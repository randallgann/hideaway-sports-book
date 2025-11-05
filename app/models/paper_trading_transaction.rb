class PaperTradingTransaction < ApplicationRecord
  belongs_to :paper_trading_account

  TRANSACTION_TYPES = %w[charge refund].freeze

  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :transaction_id, presence: true, uniqueness: true

  serialize :metadata, coder: JSON

  scope :charges, -> { where(transaction_type: 'charge') }
  scope :refunds, -> { where(transaction_type: 'refund') }
end
