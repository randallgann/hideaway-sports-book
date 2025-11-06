class CreateBankrolls < ActiveRecord::Migration[8.1]
  def change
    create_table :bankrolls do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.decimal :available_balance, precision: 10, scale: 2, default: 0.0, null: false
      t.decimal :locked_balance, precision: 10, scale: 2, default: 0.0, null: false
      t.string :currency, default: 'USD', null: false
      t.string :payment_processor, default: 'paper_trading', null: false

      t.timestamps
    end
  end
end
