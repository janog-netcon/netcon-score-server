class AvailableProblemEnvironmentNotExists < GraphQL::ExecutionError
  def initialize(problem_id)
    super("Available ProblemEnvironment for Problem(#{problem_id}) does not exist")
  end
end
