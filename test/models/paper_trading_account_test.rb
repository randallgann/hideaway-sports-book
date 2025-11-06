require "test_helper"

class PaperTradingAccountTest < ActiveSupport::TestCase
  test "valid paper trading account" do
    account = PaperTradingAccount.new(
      customer_id: "test_123",
      balance: 1000.00,
      currency: 'USD'
    )

    assert account.valid?
  end

  test "requires customer_id" do
    account = PaperTradingAccount.new(balance: 1000.00)
    assert_not account.valid?
    assert_includes account.errors[:customer_id], "can't be blank"
  end

  test "customer_id must be unique" do
    PaperTradingAccount.create!(customer_id: "test_123", balance: 1000.00)
    duplicate = PaperTradingAccount.new(customer_id: "test_123", balance: 500.00)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:customer_id], "has already been taken"
  end

  test "balance cannot be negative" do
    account = PaperTradingAccount.new(
      customer_id: "test_123",
      balance: -100.00
    )

    assert_not account.valid?
  end

  test "find_or_create_for_customer creates account if not exists" do
    account = PaperTradingAccount.find_or_create_for_customer("new_customer")

    assert account.persisted?
    assert_equal "new_customer", account.customer_id
    assert_equal 1000.00, account.balance # Default
    assert_equal 'USD', account.currency
  end

  test "find_or_create_for_customer finds existing account" do
    existing = PaperTradingAccount.create!(
      customer_id: "existing",
      balance: 500.00
    )

    found = PaperTradingAccount.find_or_create_for_customer("existing")

    assert_equal existing.id, found.id
    assert_equal 500.00, found.balance # Preserves existing balance
  end

  test "find_or_create_for_customer with custom starting balance" do
    account = PaperTradingAccount.find_or_create_for_customer(
      "custom",
      starting_balance: 2000.00,
      currency: 'EUR'
    )

    assert_equal 2000.00, account.balance
    assert_equal 'EUR', account.currency
  end

  test "debit! reduces balance" do
    account = PaperTradingAccount.create!(
      customer_id: "test",
      balance: 1000.00
    )

    account.debit!(250.00)

    assert_equal 750.00, account.reload.balance
  end

  test "debit! raises error if insufficient funds" do
    account = PaperTradingAccount.create!(
      customer_id: "test",
      balance: 100.00
    )

    assert_raises(PaymentAdapters::BaseAdapter::InsufficientFundsError) do
      account.debit!(200.00)
    end
  end

  test "credit! increases balance" do
    account = PaperTradingAccount.create!(
      customer_id: "test",
      balance: 1000.00
    )

    account.credit!(250.00)

    assert_equal 1250.00, account.reload.balance
  end

  test "has many paper_trading_transactions" do
    account = PaperTradingAccount.create!(customer_id: "test")

    assert_respond_to account, :paper_trading_transactions
  end

  test "destroys transactions when account is destroyed" do
    account = PaperTradingAccount.create!(customer_id: "test")
    transaction = account.paper_trading_transactions.create!(
      transaction_type: 'charge',
      amount: 50.00,
      currency: 'USD',
      transaction_id: 'txn_123'
    )

    account.destroy

    assert_nil PaperTradingTransaction.find_by(id: transaction.id)
  end
end
