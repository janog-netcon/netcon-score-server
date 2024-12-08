# frozen_string_literal: true

require 'English'
module Mutations
  class AcquireProblemEnvironment < BaseMutation
    field :problem_environments, [Types::ProblemEnvironmentType], null: true

    # find key
    argument :problem_id, ID,      required: true

    # 通知無効
    argument :silent,     Boolean, required: false, default_value: false

    def resolve(problem_id:, silent:) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      # for local problem
      if Config.local_problem_codes.split(',').include?(problem.code)
        return { problem_environments: nil }
      end

      # トランザクション外なので、同時にリクエストされた場合、同時に問題環境が作成される可能性がある
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

        raise $ERROR_INFO
      end

      response_json = JSON.parse(res.body)
      pe = ProblemEnvironment.create(
        host: response_json['host'],
        user: response_json['user'],
        password: response_json['password'],
        problem_id: problem_id,
        team: self.current_team!,
        secret_text: '',
        name: response_json['name'],
        service: 'SSH',
        port: response_json['port'],
        status: 'UNDER_CHALLENGE'
      )

      Notification.notify(mutation: self.graphql_name, record: [pe]) unless silent

      { problem_environments: [pe] }
    end
  end
end
