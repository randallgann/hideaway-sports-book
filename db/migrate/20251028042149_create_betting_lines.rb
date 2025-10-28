class CreateBettingLines < ActiveRecord::Migration[8.1]
  def change
    create_table :betting_lines do |t|
      t.references :game, null: false, foreign_key: true
      t.string :line_type
      t.decimal :home_odds, precision: 8, scale: 2
      t.decimal :away_odds, precision: 8, scale: 2
      t.decimal :spread, precision: 8, scale: 2
      t.decimal :total, precision: 8, scale: 2
      t.decimal :over_odds, precision: 8, scale: 2
      t.decimal :under_odds, precision: 8, scale: 2

      t.timestamps
    end
  end
end
