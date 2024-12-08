# frozen_string_literal: true

class ProblemEnvironmentAlreadyAssigned < GraphQL::ExecutionError
  def initialize(team)
    super("team(#{team.id}) has already assigned problem environment")
  end
end
