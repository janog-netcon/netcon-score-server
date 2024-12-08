class ChangeTextToUnlimited < ActiveRecord::Migration[6.0]
  def change
    # rubocop:disable Rails/BulkChangeTable
    change_column :categories,           :description, :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :issue_comments,       :text,        :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :notices,              :text,        :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :problem_bodies,       :text,        :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :problem_environments, :password,    :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :problem_environments, :secret_text, :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :problem_supplements,  :text,        :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :problems,             :secret_text, :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    change_column :teams,                :secret_text, :string, limit: nil # rubocop:disable Rails/ReversibleMigration
    # rubocop:enable Rails/BulkChangeTable
  end
end
