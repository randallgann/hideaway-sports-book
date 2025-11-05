require "test_helper"

class PaymentAdapters::FactoryTest < ActiveSupport::TestCase
  test "create returns correct adapter type for paper_trading" do
    adapter = PaymentAdapters::Factory.create(:paper_trading)

    assert_instance_of PaymentAdapters::PaperTradingAdapter, adapter
  end

  test "create returns correct adapter type for stripe" do
    # Stub the Stripe configuration check
    ENV['STRIPE_SECRET_KEY'] = 'sk_test_fake'

    adapter = PaymentAdapters::Factory.create(:stripe)

    assert_instance_of PaymentAdapters::StripeAdapter, adapter
  ensure
    ENV.delete('STRIPE_SECRET_KEY')
  end

  test "create returns correct adapter type for paypal" do
    # Stub the PayPal configuration check
    ENV['PAYPAL_CLIENT_ID'] = 'fake_client_id'
    ENV['PAYPAL_CLIENT_SECRET'] = 'fake_client_secret'

    adapter = PaymentAdapters::Factory.create(:paypal)

    assert_instance_of PaymentAdapters::PaypalAdapter, adapter
  ensure
    ENV.delete('PAYPAL_CLIENT_ID')
    ENV.delete('PAYPAL_CLIENT_SECRET')
  end

  test "create with string adapter type" do
    adapter = PaymentAdapters::Factory.create('paper_trading')

    assert_instance_of PaymentAdapters::PaperTradingAdapter, adapter
  end

  test "create with config options" do
    adapter = PaymentAdapters::Factory.create(:paper_trading, starting_balance: 500.00)

    # Test that config was passed by checking behavior
    customer_id = "test_#{SecureRandom.hex(4)}"
    result = adapter.charge(100.00, customer_id: customer_id)

    assert_equal 400.00, result[:balance] # 500 - 100
  end

  test "create raises error for unknown adapter type" do
    error = assert_raises(PaymentAdapters::Factory::AdapterNotFoundError) do
      PaymentAdapters::Factory.create(:unknown_adapter)
    end

    assert_includes error.message, "Unknown adapter type: unknown_adapter"
  end

  test "create_from_env uses PAYMENT_PROCESSOR environment variable" do
    ENV['PAYMENT_PROCESSOR'] = 'paper_trading'

    adapter = PaymentAdapters::Factory.create_from_env

    assert_instance_of PaymentAdapters::PaperTradingAdapter, adapter
  ensure
    ENV.delete('PAYMENT_PROCESSOR')
  end

  test "create_from_env defaults to paper_trading" do
    ENV.delete('PAYMENT_PROCESSOR')

    adapter = PaymentAdapters::Factory.create_from_env

    assert_instance_of PaymentAdapters::PaperTradingAdapter, adapter
  end

  test "available_adapters returns all adapter types" do
    adapters = PaymentAdapters::Factory.available_adapters

    assert_includes adapters, :paper_trading
    assert_includes adapters, :stripe
    assert_includes adapters, :paypal
    assert_equal 3, adapters.length
  end

  test "adapter_available? returns true for valid adapters" do
    assert PaymentAdapters::Factory.adapter_available?(:paper_trading)
    assert PaymentAdapters::Factory.adapter_available?(:stripe)
    assert PaymentAdapters::Factory.adapter_available?(:paypal)
    assert PaymentAdapters::Factory.adapter_available?('paper_trading')
  end

  test "adapter_available? returns false for invalid adapters" do
    assert_not PaymentAdapters::Factory.adapter_available?(:fake_adapter)
    assert_not PaymentAdapters::Factory.adapter_available?(:bitcoin)
  end

  test "adapter_info returns information about adapter" do
    info = PaymentAdapters::Factory.adapter_info(:paper_trading)

    assert_equal 'PaperTrading', info[:name]
    assert_equal :paper_trading, info[:type]
    assert_includes info[:supported_features], :charge
    assert_includes info[:supported_features], :refund
    assert_includes info[:supported_features], :withdraw
    assert_equal 'PaymentAdapters::PaperTradingAdapter', info[:class]
  end

  test "adapter_info returns nil for unknown adapter" do
    info = PaymentAdapters::Factory.adapter_info(:unknown)

    assert_nil info
  end

  test "list_all returns info for all adapters" do
    ENV['STRIPE_SECRET_KEY'] = 'sk_test_fake'
    ENV['PAYPAL_CLIENT_ID'] = 'fake_id'
    ENV['PAYPAL_CLIENT_SECRET'] = 'fake_secret'

    all_adapters = PaymentAdapters::Factory.list_all

    assert_equal 3, all_adapters.length
    assert all_adapters.key?(:paper_trading)
    assert all_adapters.key?(:stripe)
    assert all_adapters.key?(:paypal)

    # Verify each has expected structure
    all_adapters.each do |type, info|
      assert info[:name].present?
      assert info[:type].present?
      assert info[:supported_features].is_a?(Array)
      assert info[:class].present?
    end
  ensure
    ENV.delete('STRIPE_SECRET_KEY')
    ENV.delete('PAYPAL_CLIENT_ID')
    ENV.delete('PAYPAL_CLIENT_SECRET')
  end
end
