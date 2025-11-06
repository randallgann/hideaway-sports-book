class Bankroll < ApplicationRecord
  belongs_to :user
  has_many :bankroll_transactions, dependent: :destroy

  validates :available_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :locked_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :payment_processor, presence: true

  # Business rule constants
  MIN_DEPOSIT = 10.00
  MIN_WITHDRAWAL = 20.00
  MAX_TRANSACTION = 10_000.00

  # Calculate total balance
  def total_balance
    available_balance + locked_balance
  end

  # Deposit funds using payment adapter
  # @param amount [Numeric] Amount to deposit
  # @param options [Hash] Options for payment adapter
  # @return [Hash] Result with :success, :transaction, :message
  def deposit(amount, **options)
    return error_result("Deposit amount must be at least $#{MIN_DEPOSIT}") if amount < MIN_DEPOSIT
    return error_result("Deposit amount cannot exceed $#{MAX_TRANSACTION}") if amount > MAX_TRANSACTION

    # Get payment adapter
    adapter = payment_adapter

    # Process charge through payment adapter
    payment_result = adapter.charge(
      amount,
      customer_id: user.identifier,
      currency: currency,
      metadata: { bankroll_id: id, user_id: user.id }.merge(options[:metadata] || {})
    )

    unless payment_result[:success]
      return error_result("Payment failed: #{payment_result[:message]}")
    end

    # Add to available balance
    balance_before = available_balance
    self.available_balance += amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: amount,
      balance_before: balance_before,
      balance_after: available_balance,
      payment_transaction_id: payment_result[:transaction_id],
      description: "Deposit of #{amount} #{currency}",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      new_balance: available_balance,
      payment_transaction_id: payment_result[:transaction_id],
      message: "Successfully deposited #{amount} #{currency}"
    )
  rescue StandardError => e
    error_result("Deposit failed: #{e.message}")
  end

  # Withdraw funds using payment adapter
  # @param amount [Numeric] Amount to withdraw
  # @param options [Hash] Options for payment adapter
  # @return [Hash] Result with :success, :transaction, :message
  def withdraw(amount, **options)
    return error_result("Withdrawal amount must be at least $#{MIN_WITHDRAWAL}") if amount < MIN_WITHDRAWAL
    return error_result("Withdrawal amount cannot exceed $#{MAX_TRANSACTION}") if amount > MAX_TRANSACTION
    return error_result("Insufficient available balance") if available_balance < amount

    # Get payment adapter
    adapter = payment_adapter

    # Process withdrawal through payment adapter
    payment_result = adapter.withdraw(
      amount,
      customer_id: user.identifier,
      currency: currency,
      metadata: { bankroll_id: id, user_id: user.id }.merge(options[:metadata] || {})
    )

    unless payment_result[:success]
      return error_result("Withdrawal failed: #{payment_result[:message]}")
    end

    # Deduct from available balance
    balance_before = available_balance
    self.available_balance -= amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'withdrawal',
      amount: amount,
      balance_before: balance_before,
      balance_after: available_balance,
      payment_transaction_id: payment_result[:withdrawal_id],
      description: "Withdrawal of #{amount} #{currency}",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      new_balance: available_balance,
      payment_transaction_id: payment_result[:withdrawal_id],
      message: "Successfully withdrew #{amount} #{currency}"
    )
  rescue StandardError => e
    # Rollback - this shouldn't happen with proper validations
    error_result("Withdrawal failed: #{e.message}")
  end

  # Lock funds for a bet
  # @param amount [Numeric] Amount to lock
  # @param bet_id [String, Integer] Bet identifier
  # @param options [Hash] Additional options
  # @return [Hash] Result with :success, :transaction, :message
  def lock_funds_for_bet(amount, bet_id, **options)
    return error_result("Bet amount must be positive") unless amount > 0
    return error_result("Insufficient available balance to place bet") if available_balance < amount

    balance_before = available_balance

    # Move from available to locked
    self.available_balance -= amount
    self.locked_balance += amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'bet_placed',
      amount: amount,
      balance_before: balance_before,
      balance_after: available_balance,
      reference_id: bet_id.to_s,
      description: "Locked #{amount} #{currency} for bet ##{bet_id}",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      available_balance: available_balance,
      locked_balance: locked_balance,
      message: "Successfully locked #{amount} #{currency} for bet"
    )
  rescue StandardError => e
    error_result("Failed to lock funds: #{e.message}")
  end

  # Settle a winning bet
  # @param bet_id [String, Integer] Bet identifier
  # @param bet_amount [Numeric] Original bet amount
  # @param payout_amount [Numeric] Total payout (original + winnings)
  # @param options [Hash] Additional options
  # @return [Hash] Result with :success, :transaction, :message
  def settle_bet_win(bet_id, bet_amount, payout_amount, **options)
    return error_result("Invalid payout amount") unless payout_amount > 0
    return error_result("Insufficient locked balance") if locked_balance < bet_amount

    balance_before = available_balance

    # Unlock original bet and add payout to available
    self.locked_balance -= bet_amount
    self.available_balance += payout_amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'bet_won',
      amount: payout_amount,
      balance_before: balance_before,
      balance_after: available_balance,
      reference_id: bet_id.to_s,
      description: "Won bet ##{bet_id}: #{payout_amount} #{currency} (profit: #{payout_amount - bet_amount} #{currency})",
      metadata: { bet_amount: bet_amount, profit: payout_amount - bet_amount }.merge(options[:metadata] || {})
    )

    save!

    success_result(
      transaction: transaction,
      available_balance: available_balance,
      locked_balance: locked_balance,
      profit: payout_amount - bet_amount,
      message: "Bet won! Credited #{payout_amount} #{currency}"
    )
  rescue StandardError => e
    error_result("Failed to settle winning bet: #{e.message}")
  end

  # Settle a losing bet
  # @param bet_id [String, Integer] Bet identifier
  # @param bet_amount [Numeric] Original bet amount
  # @param options [Hash] Additional options
  # @return [Hash] Result with :success, :transaction, :message
  def settle_bet_loss(bet_id, bet_amount, **options)
    return error_result("Invalid bet amount") unless bet_amount > 0
    return error_result("Insufficient locked balance") if locked_balance < bet_amount

    balance_before = available_balance

    # Remove locked funds (money is gone)
    self.locked_balance -= bet_amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'bet_lost',
      amount: bet_amount,
      balance_before: balance_before,
      balance_after: available_balance,
      reference_id: bet_id.to_s,
      description: "Lost bet ##{bet_id}: #{bet_amount} #{currency}",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      available_balance: available_balance,
      locked_balance: locked_balance,
      message: "Bet lost. #{bet_amount} #{currency} deducted"
    )
  rescue StandardError => e
    error_result("Failed to settle losing bet: #{e.message}")
  end

  # Cancel a bet (unlock funds back to available)
  # @param bet_id [String, Integer] Bet identifier
  # @param bet_amount [Numeric] Original bet amount
  # @param options [Hash] Additional options
  # @return [Hash] Result with :success, :transaction, :message
  def cancel_bet(bet_id, bet_amount, **options)
    return error_result("Invalid bet amount") unless bet_amount > 0
    return error_result("Insufficient locked balance") if locked_balance < bet_amount

    balance_before = available_balance

    # Move from locked back to available
    self.locked_balance -= bet_amount
    self.available_balance += bet_amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'bet_canceled',
      amount: bet_amount,
      balance_before: balance_before,
      balance_after: available_balance,
      reference_id: bet_id.to_s,
      description: "Canceled bet ##{bet_id}: #{bet_amount} #{currency} returned",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      available_balance: available_balance,
      locked_balance: locked_balance,
      message: "Bet canceled. #{bet_amount} #{currency} returned to available balance"
    )
  rescue StandardError => e
    error_result("Failed to cancel bet: #{e.message}")
  end

  # Settle a push (tie) - return original bet
  # @param bet_id [String, Integer] Bet identifier
  # @param bet_amount [Numeric] Original bet amount
  # @param options [Hash] Additional options
  # @return [Hash] Result with :success, :transaction, :message
  def settle_bet_push(bet_id, bet_amount, **options)
    # A push is essentially the same as canceling - return the bet amount
    return error_result("Invalid bet amount") unless bet_amount > 0
    return error_result("Insufficient locked balance") if locked_balance < bet_amount

    balance_before = available_balance

    # Move from locked back to available
    self.locked_balance -= bet_amount
    self.available_balance += bet_amount

    # Record transaction
    transaction = bankroll_transactions.create!(
      transaction_type: 'bet_push',
      amount: bet_amount,
      balance_before: balance_before,
      balance_after: available_balance,
      reference_id: bet_id.to_s,
      description: "Bet ##{bet_id} pushed: #{bet_amount} #{currency} returned",
      metadata: options[:metadata] || {}
    )

    save!

    success_result(
      transaction: transaction,
      available_balance: available_balance,
      locked_balance: locked_balance,
      message: "Bet pushed. #{bet_amount} #{currency} returned"
    )
  rescue StandardError => e
    error_result("Failed to settle push: #{e.message}")
  end

  # Get transaction history
  # @param limit [Integer] Number of transactions to return
  # @return [ActiveRecord::Relation] Recent transactions
  def transaction_history(limit: 10)
    bankroll_transactions.recent(limit)
  end

  # Get summary statistics
  # @return [Hash] Statistics about the bankroll
  def stats
    {
      available_balance: available_balance,
      locked_balance: locked_balance,
      total_balance: total_balance,
      currency: currency,
      total_deposits: bankroll_transactions.deposits.sum(:amount),
      total_withdrawals: bankroll_transactions.withdrawals.sum(:amount),
      total_bets_placed: bankroll_transactions.where(transaction_type: 'bet_placed').count,
      total_bets_won: bankroll_transactions.where(transaction_type: 'bet_won').count,
      total_bets_lost: bankroll_transactions.where(transaction_type: 'bet_lost').count,
      net_profit: calculate_net_profit
    }
  end

  private

  # Get the payment adapter instance
  def payment_adapter
    @payment_adapter ||= PaymentAdapters::Factory.create(payment_processor.to_sym)
  end

  # Calculate net profit from betting (not including deposits/withdrawals)
  def calculate_net_profit
    winnings = bankroll_transactions.where(transaction_type: 'bet_won').sum(:amount)
    losses = bankroll_transactions.where(transaction_type: 'bet_lost').sum(:amount)
    winnings - losses
  end

  # Build success result hash
  def success_result(**data)
    { success: true }.merge(data)
  end

  # Build error result hash
  def error_result(message)
    { success: false, message: message }
  end
end
