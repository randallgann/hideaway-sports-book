require "test_helper"

class PaymentAdapters::PaperTradingAdapterTest < ActiveSupport::TestCase
  def setup
    @adapter = PaymentAdapters::PaperTradingAdapter.new
    @customer_id = "test_customer_#{SecureRandom.hex(4)}"
  end

  test "charge creates account if it doesn't exist" do
    result = @adapter.charge(50.00, customer_id: @customer_id)

    assert result[:success]
    assert_equal 50.00, result[:amount]
    assert result[:transaction_id].present?
    assert_equal 950.00, result[:balance] # Starting balance 1000 - 50
  end

  test "charge with insufficient funds fails" do
    # First charge to create account
    @adapter.charge(100.00, customer_id: @customer_id)

    # Try to charge more than balance
    result = @adapter.charge(1000.00, customer_id: @customer_id)

    assert_not result[:success]
    assert_includes result[:message], "Insufficient funds"
  end

  test "charge with invalid amount fails" do
    assert_raises(ArgumentError) do
      @adapter.charge(-10.00, customer_id: @customer_id)
    end

    assert_raises(ArgumentError) do
      @adapter.charge(0, customer_id: @customer_id)
    end
  end

  test "charge without customer_id fails" do
    assert_raises(ArgumentError) do
      @adapter.charge(50.00)
    end
  end

  test "refund returns money to account" do
    # First charge
    charge_result = @adapter.charge(50.00, customer_id: @customer_id)
    transaction_id = charge_result[:transaction_id]

    # Then refund
    refund_result = @adapter.refund(transaction_id, amount: 30.00)

    assert refund_result[:success]
    assert_equal 30.00, refund_result[:amount]
    assert_equal 980.00, refund_result[:balance] # 1000 - 50 + 30
  end

  test "full refund without amount specified" do
    charge_result = @adapter.charge(50.00, customer_id: @customer_id)
    transaction_id = charge_result[:transaction_id]

    refund_result = @adapter.refund(transaction_id)

    assert refund_result[:success]
    assert_equal 50.00, refund_result[:amount]
    assert_equal 1000.00, refund_result[:balance] # Back to starting balance
  end

  test "refund more than original charge fails" do
    charge_result = @adapter.charge(50.00, customer_id: @customer_id)
    transaction_id = charge_result[:transaction_id]

    refund_result = @adapter.refund(transaction_id, amount: 100.00)

    assert_not refund_result[:success]
    assert_includes refund_result[:message], "cannot exceed original charge"
  end

  test "refund non-existent transaction fails" do
    result = @adapter.refund("fake_transaction_id")

    assert_not result[:success]
    assert_includes result[:message], "not found"
  end

  test "withdraw adds to balance (payout to customer)" do
    # First charge to create account and take initial payment
    @adapter.charge(100.00, customer_id: @customer_id)
    # Balance after charge: 1000 - 100 = 900

    # Then withdraw (payout winnings back to customer)
    result = @adapter.withdraw(50.00, customer_id: @customer_id)

    assert result[:success]
    assert_equal 50.00, result[:amount]
    assert_equal 950.00, result[:balance] # 900 + 50 (payout) = 950
  end

  test "withdraw without existing account fails" do
    # Try to withdraw to non-existent account
    result = @adapter.withdraw(50.00, customer_id: @customer_id)

    assert_not result[:success]
    assert_includes result[:message], "No payment account found"
  end

  test "withdraw without customer_id fails" do
    assert_raises(ArgumentError) do
      @adapter.withdraw(50.00)
    end
  end

  test "get_balance returns account balance" do
    # Create account with charge
    @adapter.charge(200.00, customer_id: @customer_id)

    result = @adapter.get_balance(@customer_id)

    assert result[:success]
    assert_equal 800.00, result[:balance] # 1000 - 200
    assert_equal 'USD', result[:currency]
  end

  test "get_balance creates account if not exists" do
    result = @adapter.get_balance(@customer_id)

    assert result[:success]
    assert_equal 1000.00, result[:balance] # Default starting balance
  end

  test "create_customer with custom starting balance" do
    result = @adapter.create_customer(
      customer_id: @customer_id,
      starting_balance: 500.00,
      currency: 'USD'
    )

    assert result[:success]
    assert_equal 500.00, result[:balance]
    assert_equal 'USD', result[:currency]
  end

  test "validate_payment_method always returns true" do
    assert @adapter.validate_payment_method("anything")
    assert @adapter.validate_payment_method(nil)
    assert @adapter.validate_payment_method({})
  end

  test "adapter name" do
    assert_equal "PaperTrading", @adapter.name
  end

  test "supports expected features" do
    assert @adapter.supports?(:charge)
    assert @adapter.supports?(:refund)
    assert @adapter.supports?(:withdraw)
    assert @adapter.supports?(:balance)
    assert @adapter.supports?(:instant_settlement)
    assert @adapter.supports?(:zero_fees)
  end

  test "transactions are recorded in database" do
    charge_result = @adapter.charge(50.00, customer_id: @customer_id)

    account = PaperTradingAccount.find_by(customer_id: @customer_id)
    assert account.present?

    transaction = PaperTradingTransaction.find_by(transaction_id: charge_result[:transaction_id])
    assert transaction.present?
    assert_equal 'charge', transaction.transaction_type
    assert_equal 50.00, transaction.amount
  end

  test "custom starting balance configuration" do
    custom_adapter = PaymentAdapters::PaperTradingAdapter.new(starting_balance: 2000.00)
    customer_id = "custom_#{SecureRandom.hex(4)}"

    result = custom_adapter.charge(100.00, customer_id: customer_id)

    assert_equal 1900.00, result[:balance] # 2000 - 100
  end
end
