class AddLeaderboardFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Counter caches for performance
    add_column :users, :bets_count, :integer, default: 0, null: false
    add_column :users, :won_bets_count, :integer, default: 0, null: false
    add_column :users, :lost_bets_count, :integer, default: 0, null: false
    add_column :users, :push_bets_count, :integer, default: 0, null: false

    # Privacy opt-out
    add_column :users, :show_on_leaderboard, :boolean, default: true, null: false

    # Index for leaderboard privacy filter
    add_index :users, :show_on_leaderboard
  end
end
