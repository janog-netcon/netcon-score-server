class AddProjectAndZoneToProjectEnvironment < ActiveRecord::Migration[6.0]
  def change
    add_column :problem_environments, :project, :string # rubocop:disable Rails/BulkChangeTable
    add_column :problem_environments, :zone, :string
  end
end
