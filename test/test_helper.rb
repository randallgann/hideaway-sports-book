ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "vcr"
require "minitest/mock"

# Configure VCR for recording HTTP interactions (use explicitly in integration tests)
VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.filter_sensitive_data('<ODDS_API_KEY>') { ENV['ODDS_API_KEY'] }
  config.ignore_localhost = true
end

# Disable real HTTP connections by default, allow WebMock stubs
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
