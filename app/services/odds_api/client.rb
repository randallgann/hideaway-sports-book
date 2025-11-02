require 'httparty'

module OddsApi
  class Client
    include HTTParty
    base_uri 'https://api.the-odds-api.com/v4'

    attr_reader :api_key, :requests_remaining, :requests_used

    # Custom error classes
    class ApiError < StandardError; end
    class MissingApiKeyError < ApiError; end
    class UnauthorizedError < ApiError; end
    class NotFoundError < ApiError; end
    class RateLimitError < ApiError; end
    class TimeoutError < ApiError; end

    def initialize(api_key: ENV['ODDS_API_KEY'])
      @api_key = api_key
      raise MissingApiKeyError, "ODDS_API_KEY environment variable is not set" if @api_key.nil? || @api_key.empty?

      @requests_remaining = nil
      @requests_used = nil
    end

    # Fetch list of available sports
    # Returns an array of sport objects
    def fetch_sports
      response = make_request(sports_url, {})
      parse_response(response)
    end

    # Fetch odds for a specific sport
    # @param sport [String] Sport key (e.g., "basketball_nba")
    # @param regions [Array<String>] Regions to fetch odds from (default: ["us"])
    # @param markets [Array<String>] Markets to include (default: ["h2h", "spreads", "totals"])
    # @param odds_format [String] Format for odds (default: "american")
    # Returns an array of event objects with odds
    def fetch_odds(sport, regions: ["us"], markets: ["h2h", "spreads", "totals"], odds_format: "american")
      params = {
        regions: regions.join(','),
        markets: markets.join(','),
        oddsFormat: odds_format
      }

      response = make_request(odds_url(sport), params)
      parse_response(response)
    end

    private

    def sports_url
      "#{self.class.base_uri}/sports/"
    end

    def odds_url(sport)
      "#{self.class.base_uri}/sports/#{sport}/odds/"
    end

    def make_request(endpoint, params)
      query_params = params.merge(apiKey: @api_key)

      begin
        response = self.class.get(endpoint, query: query_params, timeout: 10)
        update_rate_limit_info(response.headers)
        response
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, "Request timed out"
      end
    end

    def parse_response(response)
      case response.code
      when 200
        JSON.parse(response.body)
      when 401
        error_message = parse_error_message(response)
        raise UnauthorizedError, "Invalid API key: #{error_message}"
      when 404
        error_message = parse_error_message(response)
        raise NotFoundError, "Sport not found: #{error_message}"
      when 429
        error_message = parse_error_message(response)
        raise RateLimitError, "Rate limit exceeded: #{error_message}"
      else
        raise ApiError, "API returned error: #{response.code} - #{response.body}"
      end
    end

    def parse_error_message(response)
      begin
        parsed = JSON.parse(response.body)
        parsed['message'] || response.body
      rescue JSON::ParserError
        response.body
      end
    end

    def update_rate_limit_info(headers)
      @requests_remaining = headers['x-requests-remaining'].to_i if headers['x-requests-remaining']
      @requests_used = headers['x-requests-used'].to_i if headers['x-requests-used']
    end
  end
end
