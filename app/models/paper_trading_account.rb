class PaperTradingAccount < ApplicationRecord
  has_many :paper_trading_transactions, dependent: :destroy

  validates :customer_id, presence: true, uniqueness: true
  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true

  # Find or create an account for a customer with a starting balance
  def self.find_or_create_for_customer(customer_id, starting_balance: 1000.0, currency: 'USD')
    find_or_create_by!(customer_id: customer_id) do |account|
      account.balance = starting_balance
      account.currency = currency
    end
  end

  # Debit amount from account (for charges)
  def debit!(amount)
    raise PaymentAdapters::BaseAdapter::InsufficientFundsError if balance < amount

    update!(balance: balance - amount)
  end

  # Credit amount to account (for refunds)
  def credit!(amount)
    update!(balance: balance + amount)
  end
end
