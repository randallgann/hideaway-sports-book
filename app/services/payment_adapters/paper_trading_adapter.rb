module PaymentAdapters
  class PaperTradingAdapter < BaseAdapter
    # Paper trading adapter uses mock money for testing
    # Stores balances in database and provides instant settlement

    DEFAULT_STARTING_BALANCE = 1000.0

    def initialize(config = {})
      super
      @starting_balance = config[:starting_balance] || DEFAULT_STARTING_BALANCE
    end

    # Process a paper trading payment
    # @param amount [Numeric] Amount to charge in dollars
    # @param currency [String] Currency code
    # @param options [Hash] Must include :customer_id
    # @return [Hash] Payment result
    def charge(amount, currency: 'USD', **options)
      # Validate inputs first (let ArgumentError bubble up)
      validate_amount!(amount)
      customer_id = options[:customer_id]
      raise ArgumentError, "customer_id is required" unless customer_id

      # Find or create account
      account = PaperTradingAccount.find_or_create_for_customer(
        customer_id,
        starting_balance: @starting_balance,
        currency: currency
      )

      # Check sufficient funds
      if account.balance < amount
        return error_response(
          "Insufficient funds. Balance: #{account.balance}, Required: #{amount}",
          balance: account.balance,
          required: amount
        )
      end

      # Create transaction record
      transaction = PaperTradingTransaction.create!(
        paper_trading_account: account,
        transaction_type: 'charge',
        amount: amount,
        currency: currency,
        transaction_id: generate_transaction_id,
        metadata: options[:metadata] || {}
      )

      # Debit account
      account.debit!(amount)

      success_response(
        transaction_id: transaction.transaction_id,
        amount: amount,
        currency: currency,
        balance: account.reload.balance,
        message: "Successfully charged #{amount} #{currency}"
      )
    rescue ArgumentError
      raise  # Let ArgumentError bubble up for caller to handle
    rescue InsufficientFundsError => e
      error_response(e.message, balance: account&.balance)
    rescue StandardError => e
      error_response("Payment failed: #{e.message}")
    end

    # Refund a paper trading payment
    # @param transaction_id [String] Original transaction ID
    # @param amount [Numeric, nil] Amount to refund (nil for full)
    # @param options [Hash] Additional options
    # @return [Hash] Refund result
    def refund(transaction_id, amount: nil, **options)
      # Find original transaction
      original = PaperTradingTransaction.find_by!(transaction_id: transaction_id)

      unless original.transaction_type == 'charge'
        return error_response("Cannot refund a #{original.transaction_type} transaction")
      end

      # Determine refund amount
      refund_amount = amount || original.amount
      validate_amount!(refund_amount)

      if refund_amount > original.amount
        return error_response(
          "Refund amount (#{refund_amount}) cannot exceed original charge (#{original.amount})"
        )
      end

      # Get account
      account = original.paper_trading_account

      # Create refund transaction
      refund_transaction = PaperTradingTransaction.create!(
        paper_trading_account: account,
        transaction_type: 'refund',
        amount: refund_amount,
        currency: original.currency,
        transaction_id: generate_transaction_id,
        metadata: { original_transaction_id: transaction_id }.merge(options[:metadata] || {})
      )

      # Credit account
      account.credit!(refund_amount)

      success_response(
        refund_id: refund_transaction.transaction_id,
        original_transaction_id: transaction_id,
        amount: refund_amount,
        currency: original.currency,
        balance: account.reload.balance,
        message: "Successfully refunded #{refund_amount} #{original.currency}"
      )
    rescue ActiveRecord::RecordNotFound
      error_response("Transaction #{transaction_id} not found")
    rescue StandardError => e
      error_response("Refund failed: #{e.message}")
    end

    # Withdraw funds from paper trading account (payout)
    # @param amount [Numeric] Amount to withdraw
    # @param currency [String] Currency code
    # @param options [Hash] Must include :customer_id
    # @return [Hash] Withdrawal result
    def withdraw(amount, currency: 'USD', **options)
      # Validate inputs first (let ArgumentError bubble up)
      validate_amount!(amount)
      customer_id = options[:customer_id]
      raise ArgumentError, "customer_id is required" unless customer_id

      # Find existing account (must exist - can't withdraw to non-existent account)
      account = PaperTradingAccount.find_by(customer_id: customer_id)
      unless account
        return error_response("No payment account found for customer #{customer_id}. Please make a deposit first.")
      end

      # Create withdrawal transaction (payout to customer)
      withdrawal_transaction = PaperTradingTransaction.create!(
        paper_trading_account: account,
        transaction_type: 'withdrawal',
        amount: amount,
        currency: currency,
        transaction_id: generate_transaction_id,
        metadata: options[:metadata] || {}
      )

      # Credit account (withdrawal is a payout, adds money to external account)
      account.credit!(amount)

      success_response(
        withdrawal_id: withdrawal_transaction.transaction_id,
        amount: amount,
        currency: currency,
        balance: account.reload.balance,
        message: "Successfully withdrew #{amount} #{currency}"
      )
    rescue ArgumentError
      raise  # Let ArgumentError bubble up for caller to handle
    rescue InsufficientFundsError => e
      error_response(e.message, balance: account&.balance)
    rescue StandardError => e
      error_response("Withdrawal failed: #{e.message}")
    end

    # Get customer's paper trading balance
    # @param customer_id [String] Customer identifier
    # @return [Hash] Balance information
    def get_balance(customer_id)
      account = PaperTradingAccount.find_or_create_for_customer(
        customer_id,
        starting_balance: @starting_balance
      )

      success_response(
        balance: account.balance,
        currency: account.currency,
        customer_id: customer_id
      )
    rescue StandardError => e
      error_response("Failed to retrieve balance: #{e.message}")
    end

    # Create a paper trading customer account
    # @param customer_data [Hash] Customer information (must include :customer_id)
    # @return [Hash] Customer result
    def create_customer(customer_data)
      customer_id = customer_data[:customer_id] || customer_data[:id]
      raise ArgumentError, "customer_id is required" unless customer_id

      currency = customer_data[:currency] || 'USD'
      starting_balance = customer_data[:starting_balance] || @starting_balance

      account = PaperTradingAccount.find_or_create_for_customer(
        customer_id,
        starting_balance: starting_balance,
        currency: currency
      )

      success_response(
        customer_id: account.customer_id,
        balance: account.balance,
        currency: account.currency,
        message: "Paper trading account created with #{starting_balance} #{currency}"
      )
    rescue StandardError => e
      error_response("Failed to create customer: #{e.message}")
    end

    # Validate payment method (always valid for paper trading)
    # @param payment_method [String, Hash] Payment method
    # @return [Boolean] Always true for paper trading
    def validate_payment_method(payment_method)
      true
    end

    protected

    def supported_features
      [:charge, :refund, :withdraw, :balance, :customer_creation, :instant_settlement, :zero_fees]
    end

    def validate_configuration!
      # Paper trading doesn't require external API credentials
      true
    end

    # Generate a unique transaction ID
    # @return [String] Unique transaction ID
    def generate_transaction_id
      "pt_#{SecureRandom.hex(16)}"
    end
  end
end
