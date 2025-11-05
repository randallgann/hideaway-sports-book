class CreateBankrollTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :bankroll_transactions do |t|
      t.references :bankroll, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.decimal :balance_before, precision: 10, scale: 2, null: false
      t.decimal :balance_after, precision: 10, scale: 2, null: false
      t.string :reference_id
      t.string :payment_transaction_id
      t.text :description
      t.text :metadata

      t.timestamps
    end

    add_index :bankroll_transactions, :transaction_type
    add_index :bankroll_transactions, :reference_id
    add_index :bankroll_transactions, :payment_transaction_id
    add_index :bankroll_transactions, :created_at
  end
end
