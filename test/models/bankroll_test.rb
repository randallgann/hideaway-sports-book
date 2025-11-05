require "test_helper"

class BankrollTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(username: "testuser")
    @bankroll = @user.bankroll
  end

  # Basic validations
  test "valid bankroll" do
    assert @bankroll.valid?
  end

  test "available_balance cannot be negative" do
    @bankroll.available_balance = -10.00
    assert_not @bankroll.valid?
  end

  test "locked_balance cannot be negative" do
    @bankroll.locked_balance = -5.00
    assert_not @bankroll.valid?
  end

  test "requires currency" do
    @bankroll.currency = nil
    assert_not @bankroll.valid?
  end

  test "requires payment_processor" do
    @bankroll.payment_processor = nil
    assert_not @bankroll.valid?
  end

  # total_balance calculation
  test "total_balance returns sum of available and locked" do
    @bankroll.update!(available_balance: 100.00, locked_balance: 25.00)
    assert_equal 125.00, @bankroll.total_balance
  end

  # Deposit tests
  test "deposit adds to available balance" do
    result = @bankroll.deposit(100.00)

    assert result[:success]
    assert_equal 100.00, @bankroll.reload.available_balance
    assert result[:transaction].present?
    assert_equal 'deposit', result[:transaction].transaction_type
  end

  test "deposit fails with amount below minimum" do
    result = @bankroll.deposit(5.00) # Below MIN_DEPOSIT of 10.00

    assert_not result[:success]
    assert_includes result[:message], "at least"
  end

  test "deposit fails with amount above maximum" do
    result = @bankroll.deposit(15_000.00) # Above MAX_TRANSACTION of 10,000.00

    assert_not result[:success]
    assert_includes result[:message], "cannot exceed"
  end

  test "deposit creates bankroll transaction" do
    @bankroll.deposit(100.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'deposit', transaction.transaction_type
    assert_equal 100.00, transaction.amount
    assert_equal 0.00, transaction.balance_before
    assert_equal 100.00, transaction.balance_after
  end

  # Withdrawal tests
  test "withdraw deducts from available balance" do
    @bankroll.update!(available_balance: 100.00)

    result = @bankroll.withdraw(50.00)

    assert result[:success]
    assert_equal 50.00, @bankroll.reload.available_balance
  end

  test "withdraw fails with insufficient balance" do
    @bankroll.update!(available_balance: 10.00)

    result = @bankroll.withdraw(50.00)

    assert_not result[:success]
    assert_includes result[:message], "Insufficient"
  end

  test "withdraw fails with amount below minimum" do
    @bankroll.update!(available_balance: 100.00)

    result = @bankroll.withdraw(15.00) # Below MIN_WITHDRAWAL of 20.00

    assert_not result[:success]
    assert_includes result[:message], "at least"
  end

  test "withdraw creates bankroll transaction" do
    @bankroll.update!(available_balance: 100.00)
    @bankroll.withdraw(50.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'withdrawal', transaction.transaction_type
    assert_equal 50.00, transaction.amount
    assert_equal 100.00, transaction.balance_before
    assert_equal 50.00, transaction.balance_after
  end

  # lock_funds_for_bet tests
  test "lock_funds_for_bet moves funds from available to locked" do
    @bankroll.update!(available_balance: 100.00)

    result = @bankroll.lock_funds_for_bet(25.00, 'bet_123')

    assert result[:success]
    @bankroll.reload
    assert_equal 75.00, @bankroll.available_balance
    assert_equal 25.00, @bankroll.locked_balance
  end

  test "lock_funds_for_bet fails with insufficient available balance" do
    @bankroll.update!(available_balance: 10.00)

    result = @bankroll.lock_funds_for_bet(25.00, 'bet_123')

    assert_not result[:success]
    assert_includes result[:message], "Insufficient"
  end

  test "lock_funds_for_bet creates transaction with reference_id" do
    @bankroll.update!(available_balance: 100.00)
    @bankroll.lock_funds_for_bet(25.00, 'bet_123')

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'bet_placed', transaction.transaction_type
    assert_equal 25.00, transaction.amount
    assert_equal 'bet_123', transaction.reference_id
  end

  # settle_bet_win tests
  test "settle_bet_win unlocks funds and adds payout" do
    @bankroll.update!(available_balance: 75.00, locked_balance: 25.00)

    # Won $55 total (original $25 + $30 profit)
    result = @bankroll.settle_bet_win('bet_123', 25.00, 55.00)

    assert result[:success]
    @bankroll.reload
    assert_equal 130.00, @bankroll.available_balance # 75 + 55
    assert_equal 0.00, @bankroll.locked_balance
    assert_equal 30.00, result[:profit]
  end

  test "settle_bet_win fails with insufficient locked balance" do
    @bankroll.update!(available_balance: 100.00, locked_balance: 10.00)

    result = @bankroll.settle_bet_win('bet_123', 25.00, 55.00)

    assert_not result[:success]
    assert_includes result[:message], "Insufficient locked"
  end

  test "settle_bet_win creates transaction" do
    @bankroll.update!(available_balance: 75.00, locked_balance: 25.00)
    @bankroll.settle_bet_win('bet_123', 25.00, 55.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'bet_won', transaction.transaction_type
    assert_equal 55.00, transaction.amount
    assert_equal 'bet_123', transaction.reference_id
  end

  # settle_bet_loss tests
  test "settle_bet_loss removes locked funds" do
    @bankroll.update!(available_balance: 75.00, locked_balance: 25.00)

    result = @bankroll.settle_bet_loss('bet_123', 25.00)

    assert result[:success]
    @bankroll.reload
    assert_equal 75.00, @bankroll.available_balance # Unchanged
    assert_equal 0.00, @bankroll.locked_balance # Deducted
  end

  test "settle_bet_loss fails with insufficient locked balance" do
    @bankroll.update!(locked_balance: 10.00)

    result = @bankroll.settle_bet_loss('bet_123', 25.00)

    assert_not result[:success]
  end

  test "settle_bet_loss creates transaction" do
    @bankroll.update!(locked_balance: 25.00)
    @bankroll.settle_bet_loss('bet_123', 25.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'bet_lost', transaction.transaction_type
    assert_equal 25.00, transaction.amount
    assert_equal 'bet_123', transaction.reference_id
  end

  # cancel_bet tests
  test "cancel_bet returns locked funds to available" do
    @bankroll.update!(available_balance: 75.00, locked_balance: 25.00)

    result = @bankroll.cancel_bet('bet_123', 25.00)

    assert result[:success]
    @bankroll.reload
    assert_equal 100.00, @bankroll.available_balance
    assert_equal 0.00, @bankroll.locked_balance
  end

  test "cancel_bet creates transaction" do
    @bankroll.update!(locked_balance: 25.00)
    @bankroll.cancel_bet('bet_123', 25.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'bet_canceled', transaction.transaction_type
    assert_equal 25.00, transaction.amount
    assert_equal 'bet_123', transaction.reference_id
  end

  # settle_bet_push tests
  test "settle_bet_push returns locked funds to available" do
    @bankroll.update!(available_balance: 75.00, locked_balance: 25.00)

    result = @bankroll.settle_bet_push('bet_123', 25.00)

    assert result[:success]
    @bankroll.reload
    assert_equal 100.00, @bankroll.available_balance
    assert_equal 0.00, @bankroll.locked_balance
  end

  test "settle_bet_push creates transaction" do
    @bankroll.update!(locked_balance: 25.00)
    @bankroll.settle_bet_push('bet_123', 25.00)

    transaction = @bankroll.bankroll_transactions.last
    assert_equal 'bet_push', transaction.transaction_type
    assert_equal 25.00, transaction.amount
    assert_equal 'bet_123', transaction.reference_id
  end

  # transaction_history tests
  test "transaction_history returns recent transactions" do
    @bankroll.update!(available_balance: 100.00)
    @bankroll.lock_funds_for_bet(25.00, 'bet_1')
    @bankroll.lock_funds_for_bet(25.00, 'bet_2')
    @bankroll.lock_funds_for_bet(25.00, 'bet_3')

    history = @bankroll.transaction_history(limit: 2)

    assert_equal 2, history.length
    assert_equal 'bet_3', history.first.reference_id # Most recent first
  end

  # stats tests
  test "stats returns comprehensive statistics" do
    @bankroll.update!(available_balance: 100.00)

    # Simulate some activity
    @bankroll.lock_funds_for_bet(25.00, 'bet_1')
    @bankroll.update!(locked_balance: 25.00)
    @bankroll.settle_bet_win('bet_1', 25.00, 55.00)

    @bankroll.reload
    @bankroll.lock_funds_for_bet(25.00, 'bet_2')
    @bankroll.update!(locked_balance: 25.00)
    @bankroll.settle_bet_loss('bet_2', 25.00)

    stats = @bankroll.stats

    assert stats[:available_balance].present?
    assert stats[:locked_balance].present?
    assert stats[:total_balance].present?
    assert stats[:currency].present?
    assert_equal 2, stats[:total_bets_placed]
    assert_equal 1, stats[:total_bets_won]
    assert_equal 1, stats[:total_bets_lost]
  end

  # Association tests
  test "belongs to user" do
    assert_equal @user, @bankroll.user
  end

  test "has many bankroll_transactions" do
    @bankroll.update!(available_balance: 100.00)
    @bankroll.lock_funds_for_bet(25.00, 'bet_1')

    assert @bankroll.bankroll_transactions.any?
    assert_instance_of BankrollTransaction, @bankroll.bankroll_transactions.first
  end

  test "destroys transactions when bankroll is destroyed" do
    @bankroll.update!(available_balance: 100.00)
    @bankroll.lock_funds_for_bet(25.00, 'bet_1')
    transaction_id = @bankroll.bankroll_transactions.first.id

    @bankroll.destroy

    assert_nil BankrollTransaction.find_by(id: transaction_id)
  end

  # Business rule constants
  test "MIN_DEPOSIT constant is defined" do
    assert_equal 10.00, Bankroll::MIN_DEPOSIT
  end

  test "MIN_WITHDRAWAL constant is defined" do
    assert_equal 20.00, Bankroll::MIN_WITHDRAWAL
  end

  test "MAX_TRANSACTION constant is defined" do
    assert_equal 10_000.00, Bankroll::MAX_TRANSACTION
  end

  # Integration test: complete betting flow
  test "complete betting flow from deposit to win" do
    # Start with deposit
    result = @bankroll.deposit(100.00)
    assert result[:success]
    assert_equal 100.00, @bankroll.reload.available_balance

    # Place bet
    result = @bankroll.lock_funds_for_bet(25.00, 'bet_123')
    assert result[:success]
    @bankroll.reload
    assert_equal 75.00, @bankroll.available_balance
    assert_equal 25.00, @bankroll.locked_balance

    # Win bet (payout $55 total)
    result = @bankroll.settle_bet_win('bet_123', 25.00, 55.00)
    assert result[:success]
    @bankroll.reload
    assert_equal 130.00, @bankroll.available_balance
    assert_equal 0.00, @bankroll.locked_balance

    # Verify transaction history
    transactions = @bankroll.transaction_history(limit: 10)
    assert_equal 3, transactions.length
    assert_equal %w[bet_won bet_placed deposit], transactions.map(&:transaction_type)
  end

  test "complete betting flow from deposit to loss" do
    # Deposit
    @bankroll.deposit(100.00)

    # Place bet
    @bankroll.lock_funds_for_bet(25.00, 'bet_456')

    # Lose bet
    result = @bankroll.settle_bet_loss('bet_456', 25.00)
    assert result[:success]

    @bankroll.reload
    assert_equal 75.00, @bankroll.available_balance # 100 - 25
    assert_equal 0.00, @bankroll.locked_balance
  end
end
