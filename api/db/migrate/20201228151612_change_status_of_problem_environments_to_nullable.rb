class ChangeStatusOfProblemEnvironmentsToNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null :problem_environments, :status, true
  end
end
