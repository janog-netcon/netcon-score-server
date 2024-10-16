# frozen_string_literal: true

module Mutations
  class AddAnswer < BaseMutation
    field :answer, Types::AnswerType, null: true

    argument :problem_id, ID,         required: true
    argument :bodies,     [[String]], required: true

    def resolve(problem_id:, bodies:)
      problem = Problem.find_by(id: problem_id)
      raise RecordNotExists.new(Problem, id: problem_id) if problem.nil?

      args = { problem: problem }
      Acl.permit!(mutation: self, args: args)

      answer = Answer.new

      if answer.update(args.merge(bodies: bodies, confirming: false, team: self.current_team!))
        # for local problem
        if Config.local_problem_codes.split(",").exclude?(problem.code)
          pes = ProblemEnvironment.lock.where(problem_id: problem_id, status: "UNDER_CHALLENGE", team: self.current_team!)
          raise RecordNotExists.new(ProblemEnvironment, problem_id: problem_id, status: "UNDER_CHALLENGE", team_id: self.current_team!.id) if pes.empty?
          pes.each { |pe| pe.update!(status: "UNDER_SCORING") }
        end

        # TODO: answer.gradeをジョブで実行する -> after create hook
        answer.grade(percent: nil)
        Notification.notify(mutation: self.graphql_name, record: answer)

        # gradeでcacheにscoreが残るためreloadして消す
        { answer: answer.reload.readable(team: self.current_team!) }
      else
        add_errors(answer)
      end
    end
  end
end
