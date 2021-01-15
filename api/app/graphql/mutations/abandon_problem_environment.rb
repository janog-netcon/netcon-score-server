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

      name = pes.map(&:name).uniq.first
      problem_id = pes.first.problem_id
      machine_image_name = pes.first.machine_image_name
      vmms_base_uri = URI(Rails.configuration.vm_manegement_service_uri)

      # VM管理サービスの DELETE を叩く (ActiveJob でやる?)
      headers = {}
      if Rails.configuration.vm_manegement_service_token.present?
        headers[:authorization] = "Bearer #{Rails.configuration.vm_manegement_service_token}"
      end

      uri = vmms_base_uri + "/instance/#{name}"
      res = RestClient.delete(uri.to_s, headers)
      unless (200..299) === res.code
        # NOTE: 失敗したらあとで消せば良い
        Rails.logger.error "DELETE request to vm-management-service failed, name: #{name}, res: #{res}"
      end

      # 同じ問題の VM を再作成する
      uri = vmms_base_uri + "/instance"
      post_payload = { problem_id: problem_id, machine_image_name: machine_image_name }
      headers[:content_type] = :json
      headers[:accept] = :json
      res = RestClient.post(uri.to_s, post_payload.to_json, headers)
      unless (200..299) === res.code
        # 失敗したらどうする?
        Rails.logger.error "POST request to vm-management-service failed, problem_id: #{problem_id}, machine_image_name: #{machine_image_name}, res: #{res}"
      end

      Notification.notify(mutation: self.graphql_name, record: pes) unless silent

      { problem_environments: pes }
    end
  end
end
