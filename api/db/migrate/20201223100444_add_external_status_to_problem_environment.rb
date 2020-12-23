class AddExternalStatusToProblemEnvironment < ActiveRecord::Migration[6.0]
  def change
    add_column :problem_environments, :external_status, :string
  end
end
