class ChangeNullableOfTeamTable < ActiveRecord::Migration[6.0]
  def change
    change_column_null :teams, :organization, false # rubocop:disable Rails/BulkChangeTable
    change_column_null :teams, :color, false
  end
end
