class AddApiFieldsToGamesAndTeams < ActiveRecord::Migration[8.1]
  def change
    # Add API tracking fields to teams
    add_column :teams, :external_id, :string
    add_column :teams, :data_source, :string, default: "manual"
    add_index :teams, :external_id, unique: true

    # Add API tracking fields to games
    add_column :games, :external_id, :string
    add_column :games, :data_source, :string, default: "manual"
    add_column :games, :last_synced_at, :datetime
    add_index :games, :external_id, unique: true
  end
end
