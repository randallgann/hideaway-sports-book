class BankrollTransaction < ApplicationRecord
  belongs_to :bankroll

  TRANSACTION_TYPES = %w[
    deposit
    withdrawal
    bet_placed
    bet_won
    bet_lost
    bet_canceled
    bet_push
  ].freeze

  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :balance_before, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :balance_after, presence: true, numericality: { greater_than_or_equal_to: 0 }

  serialize :metadata, coder: JSON

  # Scopes
  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :withdrawals, -> { where(transaction_type: 'withdrawal') }
  scope :bets, -> { where(transaction_type: %w[bet_placed bet_won bet_lost bet_canceled bet_push]) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  # Helper to determine if transaction adds money
  def credit?
    %w[deposit bet_won bet_canceled bet_push].include?(transaction_type)
  end

  # Helper to determine if transaction removes money
  def debit?
    %w[withdrawal bet_placed bet_lost].include?(transaction_type)
  end
end
