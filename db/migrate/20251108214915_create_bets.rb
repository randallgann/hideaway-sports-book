class CreateBets < ActiveRecord::Migration[8.1]
  def change
    create_table :bets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.references :betting_line, null: false, foreign_key: true

      t.string :selection, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false

      t.decimal :odds_at_placement, precision: 8, scale: 2, null: false
      t.decimal :line_value_at_placement, precision: 8, scale: 2

      t.decimal :potential_payout, precision: 10, scale: 2, null: false
      t.decimal :actual_payout, precision: 10, scale: 2

      t.string :status, null: false, default: 'pending'
      t.datetime :settled_at
      t.text :settlement_notes

      t.text :metadata

      t.timestamps
    end

    add_index :bets, [:user_id, :status]
    add_index :bets, [:game_id, :status]
    add_index :bets, :created_at
  end
end
