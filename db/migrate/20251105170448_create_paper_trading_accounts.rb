class CreatePaperTradingAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :paper_trading_accounts do |t|
      t.string :customer_id, null: false
      t.decimal :balance, precision: 10, scale: 2, default: 1000.0, null: false
      t.string :currency, default: 'USD', null: false

      t.timestamps
    end

    add_index :paper_trading_accounts, :customer_id, unique: true
  end
end
