# frozen_string_literal: true

require 'English'
module Mutations
  class ApplyScore < BaseMutation
    field :answer, Types::AnswerType, null: true

    argument :answer_id, ID,      required: true
    argument :percent,   Integer, required: false

    def resolve(answer_id:, percent:) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      answer = Answer.find_by(id: answer_id)
      raise RecordNotExists.new(Answer, id: answer_id) if answer.nil?

      Acl.permit!(mutation: self, args: {})

      # gradeでscoreレコードが作られる
      if answer.grade(percent: percent)
        Notification.notify(mutation: self.graphql_name, record: answer)

        # (JANOG47 NETCON)満点の場合 (percent == 100) のときは対応する ProblemEnvironment を削除し、同じ Problem の ProblemEnvironment を作るリクエストを叩く
        # TODO: AbandonProblemEnvironment と同じ処理をすれば良い。現状コピペ
        #       ActiveJob で共通化したら良さそう

        new_status = (percent == 100) ? 'ABANDONED' : 'UNDER_CHALLENGE'

        pes = ProblemEnvironment.transaction do
          pes = ProblemEnvironment.lock.where(problem_id: answer.problem_id, status: 'UNDER_SCORING', team_id: answer.team_id)

          # (再採点時など)問題VMがないこともあるので、許容する
          # raise RecordNotExists.new(ProblemEnvironment, problem_id: answer.problem_id, status: "UNDER_SCORING", team_id: answer.team_id) if pes.empty?
          next [] if pes.empty?

          uniq_name = pes.map(&:name).uniq
          if uniq_name.count != 1
            raise "A team #{answer.team_id}'s ProblemEnvironments (in UNDER_SCORING) for a problem should have same name, but have #{uniq_name}"
          end

          # TODO: update! で例外出たらどうなるのか確認 (add_errors(pes)) を返す必要がありそう)
          pes.each {|pe| pe.update!(status: new_status) }
        end

        if percent == 100
          Rails.logger.debug '@ApplyScore destroy vm start'

          problem_environment_name = pes.map(&:name).uniq.first

          # gateway の DELETE を叩く
          headers = {}
          headers[:accept] = :json

          delete_endpoint = Pathname(Rails.configuration.gateway_url) / "problem/#{problem_environment_name}"

          begin
            RestClient::Request.execute(method: :delete, url: delete_endpoint.to_s, headers: headers)
          rescue RestClient::ExceptionWithResponse => e
            Rails.logger.error "DELETE request to gateway failed, problem_environment_name: #{problem_environment_name}, code: #{e.response.code}, body: #{e.response.body}"
            # 問題環境が削除されている場合、404が返ることがあるが、問題環境は削除されているので問題ない
            if e.response.code != 404 # rubocop:disable Metrics/BlockNesting
              raise $ERROR_INFO
            end
          end
        end

        { answer: answer.readable(team: self.current_team!) }
      else
        add_errors(answer.score)
      end
    end
  end
end
