module PaymentAdapters
  class BaseAdapter
    # Custom error classes for payment processing
    class PaymentError < StandardError; end
    class InsufficientFundsError < PaymentError; end
    class InvalidPaymentMethodError < PaymentError; end
    class RefundError < PaymentError; end

    # Initialize with configuration options
    # @param config [Hash] Configuration options specific to the adapter
    def initialize(config = {})
      @config = config
      validate_configuration!
    end

    # Process a payment
    # @param amount [Numeric] Amount to charge in dollars (e.g., 10.50)
    # @param currency [String] Currency code (default: 'USD')
    # @param options [Hash] Additional options (customer_id, payment_method, metadata, etc.)
    # @return [Hash] Payment result with :success, :transaction_id, :amount, :message
    def charge(amount, currency: 'USD', **options)
      raise NotImplementedError, "#{self.class} must implement #charge"
    end

    # Refund a previous payment
    # @param transaction_id [String] ID of the original transaction
    # @param amount [Numeric, nil] Amount to refund (nil for full refund)
    # @param options [Hash] Additional options
    # @return [Hash] Refund result with :success, :refund_id, :amount, :message
    def refund(transaction_id, amount: nil, **options)
      raise NotImplementedError, "#{self.class} must implement #refund"
    end

    # Get customer's balance (relevant for paper trading, stored value accounts)
    # @param customer_id [String] Customer identifier
    # @return [Hash] Balance info with :balance, :currency
    def get_balance(customer_id)
      raise NotImplementedError, "#{self.class} must implement #get_balance"
    end

    # Create a customer account
    # @param customer_data [Hash] Customer information (email, name, etc.)
    # @return [Hash] Customer result with :success, :customer_id, :message
    def create_customer(customer_data)
      raise NotImplementedError, "#{self.class} must implement #create_customer"
    end

    # Validate a payment method
    # @param payment_method [String, Hash] Payment method to validate
    # @return [Boolean] True if valid
    def validate_payment_method(payment_method)
      raise NotImplementedError, "#{self.class} must implement #validate_payment_method"
    end

    # Get the name of this payment adapter
    # @return [String] Adapter name
    def name
      self.class.name.demodulize.gsub('Adapter', '')
    end

    # Check if this adapter supports a given feature
    # @param feature [Symbol] Feature to check (:refunds, :stored_balance, :subscriptions, etc.)
    # @return [Boolean] True if feature is supported
    def supports?(feature)
      supported_features.include?(feature)
    end

    protected

    attr_reader :config

    # List of features supported by this adapter
    # Override in subclasses to specify supported features
    # @return [Array<Symbol>] List of supported features
    def supported_features
      [:charge, :refund, :balance, :customer_creation, :payment_validation]
    end

    # Validate adapter configuration
    # Override in subclasses to add specific validation
    # @raise [ArgumentError] if configuration is invalid
    def validate_configuration!
      # Base implementation does nothing - override in subclasses
      true
    end

    # Build a successful response hash
    # @param data [Hash] Response data
    # @return [Hash] Standardized success response
    def success_response(**data)
      { success: true, timestamp: Time.current }.merge(data)
    end

    # Build an error response hash
    # @param message [String] Error message
    # @param data [Hash] Additional error data
    # @return [Hash] Standardized error response
    def error_response(message, **data)
      { success: false, message: message, timestamp: Time.current }.merge(data)
    end

    # Validate amount is positive
    # @param amount [Numeric] Amount to validate
    # @raise [ArgumentError] if amount is invalid
    def validate_amount!(amount)
      raise ArgumentError, "Amount must be positive" unless amount.to_f > 0
    end

    # Convert amount to cents for API calls
    # @param amount [Numeric] Amount in dollars
    # @return [Integer] Amount in cents
    def to_cents(amount)
      (amount.to_f * 100).round
    end

    # Convert amount from cents to dollars
    # @param cents [Integer] Amount in cents
    # @return [Float] Amount in dollars
    def to_dollars(cents)
      cents.to_f / 100
    end
  end
end
