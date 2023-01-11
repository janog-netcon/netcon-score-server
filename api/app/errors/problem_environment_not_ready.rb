class ProblemEnvironmentNotReady < GraphQL::ExecutionError
  def initialize(problem_id)
    super("Problem environment for problem(#{problem_id}) is not ready, please retry later")
  end
end
