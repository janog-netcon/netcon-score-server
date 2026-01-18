# frozen_string_literal: true

module Mutations
  class AcquireProblemEnvironment < BaseMutation
    field :problem_environments, [Types::ProblemEnvironmentType], null: true

    # find key
    argument :problem_id, ID,      required: true

    # 通知無効
    argument :silent,     Boolean, required: false, default_value: false

    def resolve(problem_id:, silent:)
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      # for local problem
      if Config.local_problem_codes.split(',').include?(problem.code)
        return { problem_environments: nil }
      end

      # トランザクション外なので、ここでは簡易チェックのみを行う。
      # 重複して作成した場合は、後続の処理で検知して削除する
      if ProblemEnvironment.exists?(team: self.current_team!, status: 'UNDER_CHALLENGE')
        raise ProblemEnvironmentAlreadyAssigned, self.current_team!
      end

      # すでに割り当てられた問題環境がない場合に新しい環境を gateway に作らせる

      headers = {}
      headers[:content_type] = :json
      headers[:accept] = :json

      post_endpoint = Pathname(Rails.configuration.gateway_url) / 'problem'
      post_payload = { problemName: problem.code }

      # 問題環境がない場合を正しくハンドルするために、ExceptionWithResponseを捕捉する
      begin
        res = RestClient::Request.execute(method: :post, url: post_endpoint.to_s, payload: post_payload.to_json, headers: headers)
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "POST request to gateway failed, problem_name: #{problem.code}, code: #{e.response.code}, body: #{e.response.body}"

        if e.response.code == 404
          # 問題環境がGatewayに登録されていない場合、問題が登録されていないのと同じエラーを返す
          raise RecordNotExists.new(Problem, code: problem_id)
        end
        if e.response.code == 503
          # 利用可能な問題環境がない場合、ProblemEnvironmentNotReadyを返す
          raise ProblemEnvironmentNotReady, problem_id
        end

        raise $!
      end

      response_json = JSON.parse(res.body)

      self.current_team!.with_lock do
        if ProblemEnvironment.exists?(team: self.current_team!, status: 'UNDER_CHALLENGE')
          # 競合によりすでに作成されていた場合は、今作った環境は不要なので削除する
          # 削除に失敗しても、後続の処理で例外を投げるので、ログに出すだけで良い
          # あまりお行儀は良くないが、確保されたまま残っていても別の問題環境が作成されるだけなので、再削除まではしない
          begin
            delete_endpoint = Pathname(Rails.configuration.gateway_url) / "problem/#{response_json.dig('name')}"
            RestClient::Request.execute(method: :delete, url: delete_endpoint.to_s, headers: { accept: :json })
          rescue RestClient::ExceptionWithResponse => e
            Rails.logger.error "DELETE request to gateway failed (cleanup), code: #{e.response.code}, body: #{e.response.body}"
          end

          raise ProblemEnvironmentAlreadyAssigned, self.current_team!
        end

        pe = ProblemEnvironment.create(
          host: response_json.dig('host'),
          user: response_json.dig('user'),
          password: response_json.dig('password'),
          problem_id: problem_id,
          team: self.current_team!,
          secret_text: '',
          name: response_json.dig('name'),
          service: 'SSH',
          port: response_json.dig('port'),
          status: 'UNDER_CHALLENGE'
        )

        Notification.notify(mutation: self.graphql_name, record: [pe]) unless silent

        { problem_environments: [pe] }
      end
    end
  end
end
