# Payment Adapters

This directory contains the payment processing adapter pattern implementation for the sportsbook application. The adapter pattern allows the application to support multiple payment processors (Stripe, PayPal, Paper Trading) through a unified interface.

## Architecture

### Base Adapter (`base_adapter.rb`)
The `BaseAdapter` class defines the common interface that all payment adapters must implement:

- `charge(amount, currency:, **options)` - Process a payment
- `refund(transaction_id, amount:, **options)` - Refund a payment
- `get_balance(customer_id)` - Get customer balance
- `create_customer(customer_data)` - Create a customer account
- `validate_payment_method(payment_method)` - Validate payment method

### Available Adapters

1. **PaperTradingAdapter** (`paper_trading_adapter.rb`)
   - Uses mock/practice money for testing
   - Stores balances in database (`PaperTradingAccount` model)
   - Perfect for learning and development
   - No external API dependencies
   - Default starting balance: $1000

2. **StripeAdapter** (`stripe_adapter.rb`)
   - Integration with Stripe payment processing
   - Requires Stripe API credentials
   - Currently returns mock responses (add `stripe` gem for production use)
   - Supports charges, refunds, customer creation

3. **PaypalAdapter** (`paypal_adapter.rb`)
   - Integration with PayPal payment processing
   - Requires PayPal API credentials
   - Currently returns mock responses (add PayPal SDK for production use)
   - Supports charges, refunds, OAuth flow

### Factory (`factory.rb`)
The `Factory` class provides a convenient way to create adapter instances:

```ruby
# Create specific adapter
adapter = PaymentAdapters::Factory.create(:paper_trading)

# Create from environment variable
adapter = PaymentAdapters::Factory.create_from_env

# List available adapters
PaymentAdapters::Factory.available_adapters
# => [:paper_trading, :stripe, :paypal]
```

## Usage Examples

### Basic Charge Example

```ruby
# Create adapter (paper trading for development)
adapter = PaymentAdapters::Factory.create(:paper_trading)

# Process a charge
result = adapter.charge(
  25.50,                    # amount in dollars
  currency: 'USD',
  customer_id: 'user_123',
  metadata: { bet_id: 42 }
)

if result[:success]
  puts "Charged successfully! Transaction ID: #{result[:transaction_id]}"
  puts "New balance: #{result[:balance]}"
else
  puts "Charge failed: #{result[:message]}"
end
```

### Refund Example

```ruby
adapter = PaymentAdapters::Factory.create(:paper_trading)

# Full refund
result = adapter.refund('pt_abc123def456')

# Partial refund
result = adapter.refund('pt_abc123def456', amount: 10.00)

if result[:success]
  puts "Refunded #{result[:amount]} #{result[:currency]}"
end
```

### Check Balance Example

```ruby
adapter = PaymentAdapters::Factory.create(:paper_trading)

result = adapter.get_balance('user_123')
puts "Balance: #{result[:balance]} #{result[:currency]}"
```

### Switching Adapters

To switch between payment processors, set the `PAYMENT_PROCESSOR` environment variable:

```bash
# Use paper trading (default)
PAYMENT_PROCESSOR=paper_trading

# Use Stripe (requires credentials)
PAYMENT_PROCESSOR=stripe
STRIPE_SECRET_KEY=sk_test_...

# Use PayPal (requires credentials)
PAYMENT_PROCESSOR=paypal
PAYPAL_CLIENT_ID=your_client_id
PAYPAL_CLIENT_SECRET=your_client_secret
```

Then in your code:

```ruby
# Automatically uses the configured processor
adapter = PaymentAdapters::Factory.create_from_env
```

## Configuration

### Paper Trading
No configuration required. Optionally set starting balance:

```ruby
adapter = PaymentAdapters::Factory.create(
  :paper_trading,
  starting_balance: 500.0
)
```

### Stripe
Requires API key in environment or config:

```ruby
adapter = PaymentAdapters::Factory.create(
  :stripe,
  api_key: ENV['STRIPE_SECRET_KEY']
)
```

Or set `STRIPE_SECRET_KEY` environment variable.

### PayPal
Requires client ID and secret:

```ruby
adapter = PaymentAdapters::Factory.create(
  :paypal,
  client_id: ENV['PAYPAL_CLIENT_ID'],
  client_secret: ENV['PAYPAL_CLIENT_SECRET'],
  sandbox: true
)
```

Or set `PAYPAL_CLIENT_ID` and `PAYPAL_CLIENT_SECRET` environment variables.

## Adding a New Adapter

1. Create a new adapter class that inherits from `BaseAdapter`
2. Implement all required methods: `charge`, `refund`, `get_balance`, `create_customer`, `validate_payment_method`
3. Override `supported_features` to list supported features
4. Override `validate_configuration!` to check required config
5. Add to `Factory::ADAPTERS` hash
6. Update documentation

Example skeleton:

```ruby
module PaymentAdapters
  class MyNewAdapter < BaseAdapter
    def initialize(config = {})
      super
      # Setup client/SDK
    end

    def charge(amount, currency: 'USD', **options)
      validate_amount!(amount)
      # Implement charge logic
      success_response(
        transaction_id: 'txn_123',
        amount: amount,
        currency: currency
      )
    end

    # Implement other required methods...

    protected

    def supported_features
      [:charge, :refund, :customer_creation]
    end

    def validate_configuration!
      # Check required config
    end
  end
end
```

## Database Models (Paper Trading)

### PaperTradingAccount
Stores customer balances for paper trading:

- `customer_id` - Unique customer identifier
- `balance` - Current balance (default: 1000.00)
- `currency` - Currency code (default: 'USD')

### PaperTradingTransaction
Records all transactions:

- `paper_trading_account_id` - Foreign key to account
- `transaction_type` - 'charge' or 'refund'
- `amount` - Transaction amount
- `currency` - Currency code
- `transaction_id` - Unique transaction identifier
- `metadata` - JSON metadata

## Testing

The paper trading adapter is perfect for testing payment flows without real money:

```ruby
# In tests
adapter = PaymentAdapters::Factory.create(:paper_trading)

# Create test customer with specific balance
account = PaperTradingAccount.create!(
  customer_id: 'test_user',
  balance: 100.00
)

# Test successful charge
result = adapter.charge(25.00, customer_id: 'test_user')
expect(result[:success]).to be true

# Test insufficient funds
result = adapter.charge(200.00, customer_id: 'test_user')
expect(result[:success]).to be false
```

## Production Considerations

When moving to production with real payment processors:

1. **Stripe**: Add `gem 'stripe'` to Gemfile and uncomment Stripe API calls in `stripe_adapter.rb`
2. **PayPal**: Add PayPal SDK gem and uncomment API calls in `paypal_adapter.rb`
3. **Environment Variables**: Ensure all required credentials are set
4. **Error Handling**: Implement proper error handling for API failures
5. **Webhooks**: Set up webhook handlers for payment events
6. **Logging**: Add logging for all payment transactions
7. **Security**: Never log sensitive payment details (card numbers, etc.)
8. **Testing**: Use sandbox/test modes before going live

## Feature Support Matrix

| Feature              | Paper Trading | Stripe | PayPal |
|---------------------|---------------|--------|--------|
| Charge              | ✅            | ✅     | ✅     |
| Refund              | ✅            | ✅     | ✅     |
| Balance Inquiry     | ✅            | ✅     | ⚠️     |
| Customer Creation   | ✅            | ✅     | ⚠️     |
| Payment Validation  | ✅            | ✅     | ✅     |
| Instant Settlement  | ✅            | ❌     | ❌     |
| Zero Fees           | ✅            | ❌     | ❌     |
| Subscriptions       | ❌            | ✅     | ✅     |
| Webhooks            | ❌            | ✅     | ✅     |

⚠️ = Limited or different implementation

## Learning Resources

- [Adapter Pattern](https://refactoring.guru/design-patterns/adapter)
- [Stripe API Docs](https://stripe.com/docs/api)
- [PayPal API Docs](https://developer.paypal.com/docs/api/overview/)
- [Rails Service Objects](https://www.toptal.com/ruby-on-rails/rails-service-objects-tutorial)
