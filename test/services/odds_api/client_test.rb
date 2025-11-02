require "test_helper"

class OddsApi::ClientTest < ActiveSupport::TestCase
  def setup
    @client = OddsApi::Client.new
  end

  test "initializes with API key from environment" do
    assert_equal ENV['ODDS_API_KEY'], @client.api_key
  end

  test "raises error when API key is missing" do
    # Test by passing nil explicitly
    error = assert_raises(OddsApi::Client::MissingApiKeyError) do
      OddsApi::Client.new(api_key: nil)
    end
    assert_equal "ODDS_API_KEY environment variable is not set", error.message
  end

  test "raises error when API key is empty string" do
    error = assert_raises(OddsApi::Client::MissingApiKeyError) do
      OddsApi::Client.new(api_key: "")
    end
    assert_equal "ODDS_API_KEY environment variable is not set", error.message
  end

  test "fetches list of available sports" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(
        status: 200,
        body: [
          { key: "americanfootball_nfl", title: "NFL" },
          { key: "basketball_nba", title: "NBA" }
        ].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    sports = @client.fetch_sports
    assert_equal 2, sports.length
    assert_equal "americanfootball_nfl", sports.first["key"]
    assert_equal "NBA", sports.last["title"]
  end

  test "fetches odds for a specific sport" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: {
        apiKey: ENV['ODDS_API_KEY'],
        regions: "us",
        markets: "h2h,spreads,totals",
        oddsFormat: "american"
      })
      .to_return(
        status: 200,
        body: [{
          id: "abc123",
          sport_key: "basketball_nba",
          commence_time: "2025-11-02T00:00:00Z",
          home_team: "Los Angeles Lakers",
          away_team: "Golden State Warriors",
          bookmakers: []
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    odds = @client.fetch_odds("basketball_nba")
    assert_equal 1, odds.length
    assert_equal "abc123", odds.first["id"]
    assert_equal "Los Angeles Lakers", odds.first["home_team"]
  end

  test "fetches odds with custom regions and markets" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds/")
      .with(query: {
        apiKey: ENV['ODDS_API_KEY'],
        regions: "us,uk,eu",
        markets: "h2h",
        oddsFormat: "american"
      })
      .to_return(
        status: 200,
        body: [].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    odds = @client.fetch_odds("americanfootball_nfl", regions: ["us", "uk", "eu"], markets: ["h2h"])
    assert_equal 0, odds.length
  end

  test "handles 401 unauthorized error" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(status: 401, body: { message: "Invalid API key" }.to_json)

    error = assert_raises(OddsApi::Client::UnauthorizedError) do
      @client.fetch_odds("basketball_nba")
    end
    assert_match(/Invalid API key/i, error.message)
  end

  test "handles 404 not found error" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/invalid_sport/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(status: 404, body: { message: "Sport not found" }.to_json)

    error = assert_raises(OddsApi::Client::NotFoundError) do
      @client.fetch_odds("invalid_sport")
    end
    assert_match(/Sport not found/i, error.message)
  end

  test "handles 429 rate limit error" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(
        status: 429,
        body: { message: "Rate limit exceeded" }.to_json,
        headers: { 'x-requests-remaining' => '0' }
      )

    error = assert_raises(OddsApi::Client::RateLimitError) do
      @client.fetch_odds("basketball_nba")
    end
    assert_match(/Rate limit exceeded/i, error.message)
  end

  test "handles timeout error" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_timeout

    error = assert_raises(OddsApi::Client::TimeoutError) do
      @client.fetch_odds("basketball_nba")
    end
    assert_match(/Request timed out/i, error.message)
  end

  test "handles generic HTTP errors" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(status: 500, body: "Internal Server Error")

    error = assert_raises(OddsApi::Client::ApiError) do
      @client.fetch_odds("basketball_nba")
    end
    assert_match(/500/, error.message)
  end

  test "parses response headers for rate limit info" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(
        status: 200,
        body: [].to_json,
        headers: {
          'Content-Type' => 'application/json',
          'x-requests-remaining' => '450',
          'x-requests-used' => '50'
        }
      )

    @client.fetch_sports
    assert_equal 450, @client.requests_remaining
    assert_equal 50, @client.requests_used
  end

  test "builds correct URL for sports endpoint" do
    assert_equal "https://api.the-odds-api.com/v4/sports/", @client.send(:sports_url)
  end

  test "builds correct URL for odds endpoint" do
    expected_url = "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/"
    assert_equal expected_url, @client.send(:odds_url, "basketball_nba")
  end
end
