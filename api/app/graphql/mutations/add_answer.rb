# frozen_string_literal: true

module Mutations
  class AddAnswer < BaseMutation
    field :answer, Types::AnswerType, null: true

    argument :problem_id, ID, required: true
    argument :bodies, [[String]], required: true

    def resolve(problem_id:, bodies:)
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      answer = Answer.new

      if answer.update(args.merge(bodies: bodies, confirming: false, team: self.current_team!))
        # TODO: answer.gradeをジョブで実行する -> after create hook
        answer.grade(percent: nil)
        SlackNotifierJob.perform_later(mutation: self.class.name.demodulize, obj: answer)
        { answer: answer.readable(team: self.current_team!) }
      else
        add_errors(answer)
      end
    end
  end
end
