class AddColumnsToProblemEnvironment < ActiveRecord::Migration[6.0]
  def change
    add_column :problem_environments, :machine_image_name, :string, null: true
  end
end
