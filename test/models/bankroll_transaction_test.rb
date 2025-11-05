require "test_helper"

class BankrollTransactionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(username: "testuser")
    @bankroll = @user.bankroll
    @bankroll.update!(available_balance: 100.00)
  end

  test "valid transaction" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert transaction.valid?
  end

  test "requires transaction_type" do
    transaction = @bankroll.bankroll_transactions.new(
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:transaction_type], "can't be blank"
  end

  test "transaction_type must be valid" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'invalid_type',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:transaction_type], "is not included in the list"
  end

  test "requires amount" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], "can't be blank"
  end

  test "amount must be positive" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      amount: -50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert_not transaction.valid?
  end

  test "requires balance_before" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_after: 150.00
    )

    assert_not transaction.valid?
  end

  test "requires balance_after" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00
    )

    assert_not transaction.valid?
  end

  test "balance_before can be zero" do
    transaction = @bankroll.bankroll_transactions.new(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 0.00,
      balance_after: 50.00
    )

    assert transaction.valid?
  end

  test "metadata is serialized as JSON" do
    transaction = @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00,
      metadata: { source: 'test', user_id: 123 }
    )

    transaction.reload
    assert_equal 'test', transaction.metadata['source']
    assert_equal 123, transaction.metadata['user_id']
  end

  # Test scopes
  test "deposits scope returns only deposits" do
    @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    @bankroll.bankroll_transactions.create!(
      transaction_type: 'withdrawal',
      amount: 30.00,
      balance_before: 150.00,
      balance_after: 120.00
    )

    deposits = @bankroll.bankroll_transactions.deposits

    assert_equal 1, deposits.count
    assert_equal 'deposit', deposits.first.transaction_type
  end

  test "withdrawals scope returns only withdrawals" do
    @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    @bankroll.bankroll_transactions.create!(
      transaction_type: 'withdrawal',
      amount: 30.00,
      balance_before: 150.00,
      balance_after: 120.00
    )

    withdrawals = @bankroll.bankroll_transactions.withdrawals

    assert_equal 1, withdrawals.count
    assert_equal 'withdrawal', withdrawals.first.transaction_type
  end

  test "bets scope returns bet-related transactions" do
    @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    @bankroll.bankroll_transactions.create!(
      transaction_type: 'bet_placed',
      amount: 25.00,
      balance_before: 150.00,
      balance_after: 125.00
    )

    @bankroll.bankroll_transactions.create!(
      transaction_type: 'bet_won',
      amount: 55.00,
      balance_before: 125.00,
      balance_after: 180.00
    )

    bets = @bankroll.bankroll_transactions.bets

    assert_equal 2, bets.count
    assert_includes bets.map(&:transaction_type), 'bet_placed'
    assert_includes bets.map(&:transaction_type), 'bet_won'
  end

  test "recent scope returns transactions in reverse chronological order" do
    first = @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    second = @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 30.00,
      balance_before: 150.00,
      balance_after: 180.00
    )

    recent = @bankroll.bankroll_transactions.recent(2)

    assert_equal second.id, recent.first.id
    assert_equal first.id, recent.last.id
  end

  # Test helper methods
  test "credit? returns true for credit transactions" do
    deposit = @bankroll.bankroll_transactions.new(transaction_type: 'deposit')
    bet_won = @bankroll.bankroll_transactions.new(transaction_type: 'bet_won')
    bet_canceled = @bankroll.bankroll_transactions.new(transaction_type: 'bet_canceled')
    bet_push = @bankroll.bankroll_transactions.new(transaction_type: 'bet_push')

    assert deposit.credit?
    assert bet_won.credit?
    assert bet_canceled.credit?
    assert bet_push.credit?
  end

  test "credit? returns false for debit transactions" do
    withdrawal = @bankroll.bankroll_transactions.new(transaction_type: 'withdrawal')
    bet_placed = @bankroll.bankroll_transactions.new(transaction_type: 'bet_placed')
    bet_lost = @bankroll.bankroll_transactions.new(transaction_type: 'bet_lost')

    assert_not withdrawal.credit?
    assert_not bet_placed.credit?
    assert_not bet_lost.credit?
  end

  test "debit? returns true for debit transactions" do
    withdrawal = @bankroll.bankroll_transactions.new(transaction_type: 'withdrawal')
    bet_placed = @bankroll.bankroll_transactions.new(transaction_type: 'bet_placed')
    bet_lost = @bankroll.bankroll_transactions.new(transaction_type: 'bet_lost')

    assert withdrawal.debit?
    assert bet_placed.debit?
    assert bet_lost.debit?
  end

  test "debit? returns false for credit transactions" do
    deposit = @bankroll.bankroll_transactions.new(transaction_type: 'deposit')
    bet_won = @bankroll.bankroll_transactions.new(transaction_type: 'bet_won')

    assert_not deposit.debit?
    assert_not bet_won.debit?
  end

  # Test associations
  test "belongs to bankroll" do
    transaction = @bankroll.bankroll_transactions.create!(
      transaction_type: 'deposit',
      amount: 50.00,
      balance_before: 100.00,
      balance_after: 150.00
    )

    assert_equal @bankroll, transaction.bankroll
  end

  test "transaction types constant contains all expected types" do
    expected_types = %w[deposit withdrawal bet_placed bet_won bet_lost bet_canceled bet_push]

    assert_equal expected_types, BankrollTransaction::TRANSACTION_TYPES
  end
end
