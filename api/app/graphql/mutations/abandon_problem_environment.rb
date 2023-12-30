# frozen_string_literal: true

require 'rest-client'

module Mutations
  class AbandonProblemEnvironment < BaseMutation
    field :problem_environments, [Types::ProblemEnvironmentType], null: true

    # find key
    argument :problem_id, String,  required: true

    # 通知無効
    argument :silent,     Boolean, required: false, default_value: false

    def resolve(problem_id:, silent:)
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      pes = ProblemEnvironment.transaction do
        pes = ProblemEnvironment.lock.where(problem_id: problem_id, status: "UNDER_CHALLENGE", team: self.current_team!)
        raise RecordNotExists.new(ProblemEnvironment, problem_id: problem_id, status: "UNDER_CHALLENGE", team: self.current_team!) if pes.empty?

        uniq_name = pes.map(&:name).uniq
        if uniq_name.count != 1
          raise "A team #{self.current_team!.id}'s ProblemEnvironments (in UNDER_CHALLENGE) for a problem should have same name, but have #{uniq_name}"
        end

        # TODO: update! で例外出たらどうなるのか確認 (add_errors(pes)) を返す必要がありそう)
        pes.each { |pe| pe.update!(status: "ABANDONED") }
      rescue ActiveRecord::StatementInvalid =>  e
        raise e
      end

      problem_environment_name = pes.map(&:name).uniq.first

      # gateway の DELETE を叩く
      headers = {}
      headers[:accept] = :json

      delete_endpoint = Pathname(Rails.configuration.gateway_url) / "problem/#{problem_environment_name}"

      begin
        res = RestClient::Request.execute(method: :delete, url: delete_endpoint.to_s, headers: headers)
        unless (200..299) === res.code || 404 === res.code
          # NOTE: 失敗したらあとで消せば良い
          Rails.logger.error "DELETE request to gateway failed, problem_environment_name: #{problem_environment_name}, res: #{res}"
        end
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "DELETE request to gateway failed, code: #{e.http_code}, res: #{e.response}"
      end

      Notification.notify(mutation: self.graphql_name, record: pes) unless silent

      { problem_environments: pes }
    end
  end
end
