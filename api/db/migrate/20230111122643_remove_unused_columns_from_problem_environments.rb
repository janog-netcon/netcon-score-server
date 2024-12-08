class RemoveUnusedColumnsFromProblemEnvironments < ActiveRecord::Migration[6.0]
  def change
    remove_column :problem_environments, :machine_image_name # rubocop:disable Rails/BulkChangeTable,Rails/ReversibleMigration
    remove_column :problem_environments, :external_status # rubocop:disable Rails/ReversibleMigration
    remove_column :problem_environments, :project # rubocop:disable Rails/ReversibleMigration
    remove_column :problem_environments, :zone # rubocop:disable Rails/ReversibleMigration
  end
end
