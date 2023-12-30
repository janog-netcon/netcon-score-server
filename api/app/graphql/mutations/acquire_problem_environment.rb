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
      if Config.local_problem_codes.split(",").include?(problem.code)
        return { problem_environments: nil }
      end

      # NOTE: ここはトランザクション外なので、同時に2つのリクエストが来たときは、ここで引っかからない
      if ProblemEnvironment.exists?(problem_id: problem_id, team: self.current_team!, status: "UNDER_CHALLENGE")
        raise ProblemEnvironmentAlreadyAssigned.new(self.current_team!, problem_id)
      end

      # すでに割り当てられた問題環境がない場合に新しい環境を gateway に作らせる

      headers = {}
      headers[:content_type] = :json
      headers[:accept] = :json

      post_endpoint = Pathname(Rails.configuration.gateway_url) / "problem"
      post_payload = { problemName: problem.code }

      begin
        res = RestClient::Request.execute(method: :post, url: post_endpoint.to_s, payload: post_payload.to_json, headers: headers)
        if res.code == 503
          raise ProblemEnvironmentNotReady.new(problem_id)
        end

        unless (200..299) === res.code
          # NOTE: 失敗したらあとで消せば良い
          Rails.logger.error "POST request to gateway failed, problem_code: #{problem.code}, res: #{res}"
        end
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "POST request to gateway failed, payload: #{post_payload}, code: #{e.http_code}, res: #{e.response}"
      end

      response_json = JSON.parse(res.body)

      pe = ProblemEnvironment.create(
        host: response_json.dig("host"),
        user: response_json.dig("user"),
        password: response_json.dig("password"),
        problem_id: problem_id,
        team: self.current_team!,
        secret_text: "",
        name: response_json.dig("name"),
        service: "SSH",
        port: response_json.dig("port"),
        status: "UNDER_CHALLENGE"
      )

      Notification.notify(mutation: self.graphql_name, record: [pe]) unless silent

      { problem_environments: [pe] }
    end
  end
end
