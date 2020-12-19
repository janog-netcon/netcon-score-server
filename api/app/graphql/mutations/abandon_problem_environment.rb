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
        pes = ProblemEnvironment.lock.where(problem_id: problem_id, status: "RUNNING_IN_USE", team: self.current_team!)
        raise RecordNotExists.new(ProblemEnvironment, problem_id: problem_id, status: "RUNNING_IN_USE", team: self.current_team!) if pes.empty?

        uniq_name = pes.map(&:name).uniq
        if uniq_name.count != 1
          raise "A team #{self.current_team!.id}'s ProblemEnvironments (in RUNNING_IN_USE) for a problem should have same name, but have #{uniq_name}"
        end

        # TODO: update! で例外出たらどうなるのか確認 (add_errors(pes)) を返す必要がありそう)
        pes.each { |pe| pe.update!(status: "RUNNING_ABANDONED") }
      rescue ActiveRecord::StatementInvalid =>  e
        raise e
      end

      # VM管理サービスの DELETE を叩く (ActiveJob でやる?)
      # resp = RestClient.delete "http://vm-management-service/instance/#{uniq_name.first}"
      # unless (200..299) === resp.code
      #   # 失敗したらあとで消せば良い
      # end

      # 同じ問題の VM を再作成する
      # post_payload = { problem_id: pes.first.id, machine_image_name: pes.first.machine_image_name }
      # resp = RestClient.post "http://vm-management-service/instance", post_payload.to_json, { content_type: :json, accept: :json }
      # unless (200..299) === resp.code
      #   # 失敗したらどうする?
      # end

      Notification.notify(mutation: self.graphql_name, record: pes) unless silent

      { problem_environments: pes.map{ |pe| pe.readable(team: self.current_team!) }.compact }
    end
  end
end
