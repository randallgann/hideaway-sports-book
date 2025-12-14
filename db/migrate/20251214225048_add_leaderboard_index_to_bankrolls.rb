class AddLeaderboardIndexToBankrolls < ActiveRecord::Migration[8.1]
  def change
    add_index :bankrolls, [ :available_balance, :locked_balance ],
              name: "index_bankrolls_on_balance_for_leaderboard"
  end
end
