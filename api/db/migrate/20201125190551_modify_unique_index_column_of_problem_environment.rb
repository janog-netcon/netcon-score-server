class ModifyUniqueIndexColumnOfProblemEnvironment < ActiveRecord::Migration[6.0]
  def change
    remove_index :problem_environments, column: %i[problem_id team_id name service], unique: true, name: :problem_environments_on_composit_keys
    add_index :problem_environments, %i[problem_id name service], unique: true, name: :problem_environments_on_composit_keys
  end
end
