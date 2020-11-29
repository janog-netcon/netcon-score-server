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
        { answer: answer.readable(team: self.current_team!) }

        # TODO: (JANOG47 NETCON)満点の場合 (percent == 100) のときは対応する ProblemEnvironment を削除し、同じ Problem の ProblemEnvironment を作るリクエストを叩く
        #       AbandonProblemEnvironment と同じ処理をすれば良い。最悪コピペしますが ActiveJob で共通化したら良さそう
      else
        add_errors(answer.score)
      end
    end
  end
end
