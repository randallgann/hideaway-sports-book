require "test_helper"

class OddsApi::GameImporterTest < ActiveSupport::TestCase
  def setup
    @importer = OddsApi::GameImporter.new
    @team_matcher = OddsApi::TeamMatcher.new

    # Create test teams
    @lakers = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "basketball_nba")
    @warriors = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "basketball_nba")
  end

  test "imports a new game from API data" do
    api_event = build_api_event(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      commence_time: "2025-11-05T00:00:00Z",
      sport_key: "basketball_nba"
    )

    assert_difference 'Game.count', 1 do
      game = @importer.import_event(api_event)

      assert_equal "game_abc_123", game.external_id
      assert_equal @lakers.id, game.home_team_id
      assert_equal @warriors.id, game.away_team_id
      assert_equal "basketball_nba", game.sport
      assert_equal "the_odds_api", game.data_source
      assert_equal "scheduled", game.status
      assert_not_nil game.last_synced_at
    end
  end

  test "updates existing game instead of creating duplicate" do
    existing_game = Game.create!(
      external_id: "game_abc_123",
      home_team: @lakers,
      away_team: @warriors,
      game_time: 2.days.from_now,
      sport: "basketball_nba",
      data_source: "the_odds_api"
    )

    api_event = build_api_event(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      commence_time: "2025-11-05T00:00:00Z",
      sport_key: "basketball_nba"
    )

    assert_no_difference 'Game.count' do
      game = @importer.import_event(api_event)
      assert_equal existing_game.id, game.id
    end
  end

  test "creates moneyline betting line from h2h market" do
    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          h2h: [
            { name: "Los Angeles Lakers", price: -150 },
            { name: "Golden State Warriors", price: 130 }
          ]
        })
      ]
    )

    game = @importer.import_event(api_event)

    assert_equal 1, game.betting_lines.count
    line = game.betting_lines.find_by(line_type: "moneyline")
    assert_not_nil line
    assert_equal -150, line.home_odds
    assert_equal 130, line.away_odds
  end

  test "creates spread betting line from spreads market" do
    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          spreads: [
            { name: "Los Angeles Lakers", price: -110, point: -5.5 },
            { name: "Golden State Warriors", price: -110, point: 5.5 }
          ]
        })
      ]
    )

    game = @importer.import_event(api_event)

    line = game.betting_lines.find_by(line_type: "spread")
    assert_not_nil line
    assert_equal -5.5, line.spread
    assert_equal -110, line.home_odds
    assert_equal -110, line.away_odds
  end

  test "creates over/under betting line from totals market" do
    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          totals: [
            { name: "Over", price: -115, point: 220.5 },
            { name: "Under", price: -105, point: 220.5 }
          ]
        })
      ]
    )

    game = @importer.import_event(api_event)

    line = game.betting_lines.find_by(line_type: "over_under")
    assert_not_nil line
    assert_equal 220.5, line.total
    assert_equal -115, line.over_odds
    assert_equal -105, line.under_odds
  end

  test "aggregates odds from multiple bookmakers by averaging" do
    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          h2h: [
            { name: "Los Angeles Lakers", price: -150 },
            { name: "Golden State Warriors", price: 130 }
          ]
        }),
        build_bookmaker("draftkings", {
          h2h: [
            { name: "Los Angeles Lakers", price: -160 },
            { name: "Golden State Warriors", price: 140 }
          ]
        }),
        build_bookmaker("betmgm", {
          h2h: [
            { name: "Los Angeles Lakers", price: -155 },
            { name: "Golden State Warriors", price: 135 }
          ]
        })
      ]
    )

    game = @importer.import_event(api_event)
    line = game.betting_lines.find_by(line_type: "moneyline")

    # Average: (-150 + -160 + -155) / 3 = -155
    # Average: (130 + 140 + 135) / 3 = 135
    assert_in_delta -155, line.home_odds, 1
    assert_in_delta 135, line.away_odds, 1
  end

  test "updates existing betting lines instead of creating duplicates" do
    game = Game.create!(
      external_id: "game_abc_123",
      home_team: @lakers,
      away_team: @warriors,
      game_time: 2.days.from_now,
      sport: "basketball_nba",
      data_source: "the_odds_api"
    )

    existing_line = BettingLine.create!(
      game: game,
      line_type: "moneyline",
      home_odds: -140,
      away_odds: 120
    )

    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          h2h: [
            { name: "Los Angeles Lakers", price: -150 },
            { name: "Golden State Warriors", price: 130 }
          ]
        })
      ]
    )

    assert_no_difference 'BettingLine.count' do
      game = @importer.import_event(api_event)
      existing_line.reload
      assert_equal -150, existing_line.home_odds
      assert_equal 130, existing_line.away_odds
    end
  end

  test "handles events with all three market types" do
    api_event = build_api_event_with_odds(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: [
        build_bookmaker("fanduel", {
          h2h: [
            { name: "Los Angeles Lakers", price: -150 },
            { name: "Golden State Warriors", price: 130 }
          ],
          spreads: [
            { name: "Los Angeles Lakers", price: -110, point: -5.5 },
            { name: "Golden State Warriors", price: -110, point: 5.5 }
          ],
          totals: [
            { name: "Over", price: -115, point: 220.5 },
            { name: "Under", price: -105, point: 220.5 }
          ]
        })
      ]
    )

    game = @importer.import_event(api_event)
    assert_equal 3, game.betting_lines.count
    assert game.betting_lines.exists?(line_type: "moneyline")
    assert game.betting_lines.exists?(line_type: "spread")
    assert game.betting_lines.exists?(line_type: "over_under")
  end

  test "handles events with no bookmakers gracefully" do
    api_event = build_api_event(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors",
      bookmakers: []
    )

    game = @importer.import_event(api_event)
    assert_equal 0, game.betting_lines.count
  end

  test "sets last_synced_at timestamp" do
    api_event = build_api_event(
      id: "game_abc_123",
      home_team: "Los Angeles Lakers",
      away_team: "Golden State Warriors"
    )

    travel_to Time.current do
      game = @importer.import_event(api_event)
      assert_in_delta Time.current.to_i, game.last_synced_at.to_i, 1
    end
  end

  test "imports multiple events in batch" do
    events = [
      build_api_event(id: "game_1", home_team: "Los Angeles Lakers", away_team: "Golden State Warriors"),
      build_api_event(id: "game_2", home_team: "Golden State Warriors", away_team: "Los Angeles Lakers")
    ]

    assert_difference 'Game.count', 2 do
      result = @importer.import_events(events)

      assert_equal 2, result[:games_created]
      assert_equal 0, result[:games_updated]
    end
  end

  test "tracks created vs updated games in batch import" do
    # Create one existing game
    Game.create!(
      external_id: "game_1",
      home_team: @lakers,
      away_team: @warriors,
      game_time: 2.days.from_now,
      sport: "basketball_nba",
      data_source: "the_odds_api"
    )

    events = [
      build_api_event(id: "game_1", home_team: "Los Angeles Lakers", away_team: "Golden State Warriors"),
      build_api_event(id: "game_2", home_team: "Golden State Warriors", away_team: "Los Angeles Lakers")
    ]

    result = @importer.import_events(events)

    assert_equal 1, result[:games_created]
    assert_equal 1, result[:games_updated]
  end

  private

  def build_api_event(id:, home_team:, away_team:, sport_key: "basketball_nba", commence_time: "2025-11-05T00:00:00Z", bookmakers: [])
    {
      "id" => id,
      "sport_key" => sport_key,
      "commence_time" => commence_time,
      "home_team" => home_team,
      "away_team" => away_team,
      "bookmakers" => bookmakers
    }
  end

  def build_api_event_with_odds(id:, home_team:, away_team:, bookmakers:, sport_key: "basketball_nba", commence_time: "2025-11-05T00:00:00Z")
    build_api_event(
      id: id,
      home_team: home_team,
      away_team: away_team,
      sport_key: sport_key,
      commence_time: commence_time,
      bookmakers: bookmakers
    )
  end

  def build_bookmaker(name, markets)
    bookmaker_data = {
      "key" => name,
      "title" => name.titleize,
      "markets" => []
    }

    markets.each do |market_key, outcomes|
      bookmaker_data["markets"] << {
        "key" => market_key.to_s,
        "outcomes" => outcomes.map(&:stringify_keys)
      }
    end

    bookmaker_data
  end
end
