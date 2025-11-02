require "test_helper"

class OddsApi::SportsSyncTest < ActiveSupport::TestCase
  def setup
    @sync = OddsApi::SportsSync.new
    # Create test teams to avoid unexpected API calls during team matching
    @lakers = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "basketball_nba")
    @warriors = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "basketball_nba")
  end

  test "syncs odds for a single sport" do
    stub_odds_request("basketball_nba", [build_api_event])

    result = @sync.sync_sport("basketball_nba")

    assert result[:success]
    assert_equal "basketball_nba", result[:sport]
    assert_equal 1, result[:games_created]
    assert_equal 0, result[:games_updated]
    assert result[:synced_at].present?
  end

  test "syncs multiple sports" do
    stub_odds_request("basketball_nba", [build_api_event(id: "nba_game")])
    stub_odds_request("americanfootball_nfl", [build_api_event(id: "nfl_game", sport_key: "americanfootball_nfl")])

    result = @sync.sync_all(["basketball_nba", "americanfootball_nfl"])

    assert_equal 2, result[:sports_synced]
    assert_equal 2, result[:total_games_created]
    assert_equal 0, result[:total_games_updated]
    assert_equal 0, result[:errors].length
  end

  test "handles API errors gracefully" do
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(status: 429, body: { message: "Rate limit exceeded" }.to_json)

    result = @sync.sync_sport("basketball_nba")

    assert_not result[:success]
    assert_match(/Rate limit exceeded/i, result[:error])
  end

  test "collects errors from multiple sport syncs" do
    stub_odds_request("basketball_nba", [build_api_event])
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(status: 500, body: "API error")

    result = @sync.sync_all(["basketball_nba", "americanfootball_nfl"])

    assert_equal 1, result[:sports_synced]
    assert_equal 1, result[:errors].length
    assert_equal "americanfootball_nfl", result[:errors].first[:sport]
    assert_match(/API/, result[:errors].first[:error])
  end

  test "uses correct regions and markets" do
    custom_sync = OddsApi::SportsSync.new(regions: ["us"], markets: ["h2h"])

    stub_request(:get, "https://api.the-odds-api.com/v4/sports/basketball_nba/odds/")
      .with(query: hash_including({
        apiKey: ENV['ODDS_API_KEY'],
        regions: "us",
        markets: "h2h"
      }))
      .to_return(status: 200, body: [].to_json, headers: { 'Content-Type' => 'application/json' })

    result = custom_sync.sync_sport("basketball_nba")
    assert result[:success]
  end

  test "returns empty result for empty sport list" do
    result = @sync.sync_all([])

    assert_equal 0, result[:sports_synced]
    assert_equal 0, result[:total_games_created]
    assert_equal 0, result[:total_games_updated]
    assert_equal 0, result[:errors].length
  end

  test "default sports list includes NFL, NBA, and NCAAF" do
    assert_includes OddsApi::SportsSync::DEFAULT_SPORTS, "basketball_nba"
    assert_includes OddsApi::SportsSync::DEFAULT_SPORTS, "americanfootball_nfl"
    assert_includes OddsApi::SportsSync::DEFAULT_SPORTS, "americanfootball_ncaaf"
  end

  test "sync_all uses default sports when no argument provided" do
    OddsApi::SportsSync::DEFAULT_SPORTS.each do |sport|
      stub_odds_request(sport, [])
    end

    result = @sync.sync_all

    assert_equal OddsApi::SportsSync::DEFAULT_SPORTS.length, result[:sports_synced]
  end

  private

  def stub_odds_request(sport, events)
    stub_request(:get, "https://api.the-odds-api.com/v4/sports/#{sport}/odds/")
      .with(query: hash_including({ apiKey: ENV['ODDS_API_KEY'] }))
      .to_return(
        status: 200,
        body: events.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def build_api_event(id: "game_abc", sport_key: "basketball_nba")
    {
      "id" => id,
      "sport_key" => sport_key,
      "commence_time" => "2025-11-05T00:00:00Z",
      "home_team" => "Los Angeles Lakers",
      "away_team" => "Golden State Warriors",
      "bookmakers" => []
    }
  end
end
