# frozen_string_literal: true

module Mutations
  class ApplyScore < BaseMutation
    field :answer, Types::AnswerType, null: true

    argument :answer_id, ID,      required: true
    argument :percent,   Integer, required: false

    def resolve(answer_id:, percent:)
      answer = Answer.find_by(id: answer_id)
      raise RecordNotExists.new(Answer, id: answer_id) if answer.nil?

      Acl.permit!(mutation: self, args: {})

      # gradeでscoreレコードが作られる
      if answer.grade(percent: percent)
        Notification.notify(mutation: self.graphql_name, record: answer)

        # (JANOG47 NETCON)満点の場合 (percent == 100) のときは対応する ProblemEnvironment を削除し、同じ Problem の ProblemEnvironment を作るリクエストを叩く
        # TODO: AbandonProblemEnvironment と同じ処理をすれば良い。現状コピペ
        #       ActiveJob で共通化したら良さそう

        new_status = (percent == 100) ? "ABANDONED" : "UNDER_CHALLENGE"

        pes = ProblemEnvironment.transaction do
          pes = ProblemEnvironment.lock.where(problem_id: answer.problem_id, status: "UNDER_SCORING", team_id: answer.team_id)
          raise RecordNotExists.new(ProblemEnvironment, problem_id: answer.problem_id, status: "UNDER_SCORING", team_id: answer.team_id) if pes.empty?

          uniq_name = pes.map(&:name).uniq
          if uniq_name.count != 1
            raise "A team #{answer.team_id}'s ProblemEnvironments (in UNDER_SCORING) for a problem should have same name, but have #{uniq_name}"
          end

          # TODO: update! で例外出たらどうなるのか確認 (add_errors(pes)) を返す必要がありそう)
          pes.each { |pe| pe.update!(status: new_status) }
        rescue ActiveRecord::StatementInvalid =>  e
          raise e
        end

        if percent == 100
          Rails.logger.debug "@ApplyScore destroy vm start"
          name = pes.map(&:name).uniq.first
          problem_id = answer.problem_id
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
        end

        { answer: answer.readable(team: self.current_team!) }
      else
        add_errors(answer.score)
      end
    end
  end
end
