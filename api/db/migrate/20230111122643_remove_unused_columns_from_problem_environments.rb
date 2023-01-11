class RemoveUnusedColumnsFromProblemEnvironments < ActiveRecord::Migration[6.0]
  def change
    remove_column :problem_environments, :machine_image_name
    remove_column :problem_environments, :external_status
    remove_column :problem_environments, :project
    remove_column :problem_environments, :zone
  end
end
