class CreatePaperTradingTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :paper_trading_transactions do |t|
      t.references :paper_trading_account, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.string :transaction_id, null: false
      t.text :metadata

      t.timestamps
    end

    add_index :paper_trading_transactions, :transaction_id, unique: true
    add_index :paper_trading_transactions, :transaction_type
  end
end
