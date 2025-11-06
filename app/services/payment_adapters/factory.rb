module PaymentAdapters
  class Factory
    # Factory for creating payment adapter instances
    # Supports multiple payment processors through a unified interface

    class AdapterNotFoundError < StandardError; end

    ADAPTERS = {
      paper_trading: 'PaymentAdapters::PaperTradingAdapter',
      stripe: 'PaymentAdapters::StripeAdapter',
      paypal: 'PaymentAdapters::PaypalAdapter'
    }.freeze

    class << self
      # Create a payment adapter instance
      # @param adapter_type [Symbol, String] Type of adapter (:paper_trading, :stripe, :paypal)
      # @param config [Hash] Configuration options for the adapter
      # @return [BaseAdapter] Initialized payment adapter
      # @raise [AdapterNotFoundError] if adapter type is not recognized
      #
      # @example Create a paper trading adapter
      #   adapter = PaymentAdapters::Factory.create(:paper_trading)
      #
      # @example Create a Stripe adapter with custom config
      #   adapter = PaymentAdapters::Factory.create(:stripe, api_key: 'sk_test_...')
      #
      # @example Create adapter from environment variable
      #   adapter = PaymentAdapters::Factory.create_from_env
      #
      def create(adapter_type, config = {})
        adapter_type = adapter_type.to_sym
        adapter_class_name = ADAPTERS[adapter_type]

        raise AdapterNotFoundError, "Unknown adapter type: #{adapter_type}" unless adapter_class_name

        adapter_class = adapter_class_name.constantize
        adapter_class.new(config)
      end

      # Create adapter based on environment configuration
      # Reads PAYMENT_PROCESSOR env var (defaults to 'paper_trading')
      # @param config [Hash] Optional configuration overrides
      # @return [BaseAdapter] Initialized payment adapter
      #
      # @example
      #   # With PAYMENT_PROCESSOR=stripe in .env
      #   adapter = PaymentAdapters::Factory.create_from_env
      #
      def create_from_env(config = {})
        processor = ENV.fetch('PAYMENT_PROCESSOR', 'paper_trading').to_sym
        create(processor, config)
      end

      # Get list of available adapters
      # @return [Array<Symbol>] List of available adapter types
      def available_adapters
        ADAPTERS.keys
      end

      # Check if an adapter type is available
      # @param adapter_type [Symbol, String] Type to check
      # @return [Boolean] True if available
      def adapter_available?(adapter_type)
        ADAPTERS.key?(adapter_type.to_sym)
      end

      # Get adapter information
      # @param adapter_type [Symbol, String] Type of adapter
      # @return [Hash] Information about the adapter
      def adapter_info(adapter_type)
        adapter = create(adapter_type)
        {
          name: adapter.name,
          type: adapter_type,
          supported_features: adapter.instance_eval { supported_features },
          class: adapter.class.name
        }
      rescue AdapterNotFoundError
        nil
      end

      # List all adapters with their information
      # @return [Hash] Hash of adapter_type => info
      def list_all
        available_adapters.each_with_object({}) do |adapter_type, hash|
          hash[adapter_type] = adapter_info(adapter_type)
        end
      end
    end
  end
end
