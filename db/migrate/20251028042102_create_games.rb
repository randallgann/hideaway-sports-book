class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.datetime :game_time
      t.string :sport
      t.string :status
      t.integer :home_score
      t.integer :away_score

      t.timestamps
    end
  end
end
