class ProblemEnvironmentAlreadyAssigned < GraphQL::ExecutionError
  def initialize(team, problem_id)
    super("team(#{team.id}) has already assigned problem environment to problem(#{problem_id})")
  end
end
