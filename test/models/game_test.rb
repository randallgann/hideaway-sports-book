require "test_helper"

class GameTest < ActiveSupport::TestCase
  def setup
    @home_team = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba")
    @away_team = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "nba")
  end

  test "should create valid game" do
    game = Game.new(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      status: "scheduled"
    )
    assert game.valid?
  end

  test "should have external_id attribute" do
    game = Game.new
    assert_respond_to game, :external_id
    assert_respond_to game, :external_id=
  end

  test "should have data_source attribute" do
    game = Game.new
    assert_respond_to game, :data_source
    assert_respond_to game, :data_source=
  end

  test "should have last_synced_at attribute" do
    game = Game.new
    assert_respond_to game, :last_synced_at
    assert_respond_to game, :last_synced_at=
  end

  test "data_source should default to manual" do
    game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba"
    )
    assert_equal "manual", game.data_source
  end

  test "external_id should be unique when present" do
    Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      external_id: "api_game_123"
    )

    duplicate_game = Game.new(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 2.days.from_now,
      sport: "nba",
      external_id: "api_game_123"
    )
    assert_not duplicate_game.valid?
    assert_includes duplicate_game.errors[:external_id], "has already been taken"
  end

  test "external_id can be nil" do
    game1 = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      external_id: nil
    )
    game2 = Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 2.days.from_now,
      sport: "nba",
      external_id: nil
    )

    assert game1.persisted?
    assert game2.persisted?
  end

  test "should have home_team association" do
    game = Game.new
    assert_respond_to game, :home_team
  end

  test "should have away_team association" do
    game = Game.new
    assert_respond_to game, :away_team
  end

  test "should have betting_lines association" do
    game = Game.new
    assert_respond_to game, :betting_lines
  end

  test "data_source can be set to api" do
    game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      data_source: "api"
    )
    assert_equal "api", game.data_source
  end

  test "last_synced_at can be set" do
    sync_time = Time.current
    game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      last_synced_at: sync_time
    )
    assert_in_delta sync_time.to_i, game.last_synced_at.to_i, 1
  end

  # Scope tests
  test "live_window scope returns games within 1 hour of start" do
    # Create a game starting in 30 minutes (should be in live window)
    live_game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 30.minutes.from_now,
      sport: "nba",
      external_id: "live_game"
    )

    # Create a game starting in 2 hours (should NOT be in live window)
    future_game = Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 2.hours.from_now,
      sport: "nba",
      external_id: "future_game"
    )

    live_games = Game.live_window
    assert_includes live_games, live_game
    assert_not_includes live_games, future_game
  end

  test "upcoming_window scope returns games 1-48 hours from now" do
    # Create a game in 24 hours (should be in upcoming window)
    upcoming_game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 24.hours.from_now,
      sport: "nba",
      external_id: "upcoming_game"
    )

    # Create a game in 30 minutes (should NOT be in upcoming window - too soon)
    live_game = Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 30.minutes.from_now,
      sport: "nba",
      external_id: "live_game"
    )

    # Create a game in 3 days (should NOT be in upcoming window - too far)
    distant_game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 3.days.from_now,
      sport: "nba",
      external_id: "distant_game"
    )

    upcoming_games = Game.upcoming_window
    assert_includes upcoming_games, upcoming_game
    assert_not_includes upcoming_games, live_game
    assert_not_includes upcoming_games, distant_game
  end

  test "distant_window scope returns games more than 48 hours from now" do
    # Create a game in 3 days (should be in distant window)
    distant_game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 3.days.from_now,
      sport: "nba",
      external_id: "distant_game"
    )

    # Create a game in 24 hours (should NOT be in distant window)
    upcoming_game = Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 24.hours.from_now,
      sport: "nba",
      external_id: "upcoming_game"
    )

    distant_games = Game.distant_window
    assert_includes distant_games, distant_game
    assert_not_includes distant_games, upcoming_game
  end

  test "from_api scope returns only games with external_id" do
    # Create a game from API (has external_id)
    api_game = Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 1.day.from_now,
      sport: "nba",
      external_id: "api_game_123",
      data_source: "the_odds_api"
    )

    # Create a manual game (no external_id)
    manual_game = Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 2.days.from_now,
      sport: "nba",
      external_id: nil,
      data_source: "manual"
    )

    api_games = Game.from_api
    assert_includes api_games, api_game
    assert_not_includes api_games, manual_game
  end

  # Last sync time tests
  test "last_live_sync returns most recent sync time from live window" do
    # Create a live game synced 10 minutes ago
    Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 30.minutes.from_now,
      sport: "nba",
      external_id: "live_game_1",
      last_synced_at: 10.minutes.ago
    )

    # Create another live game synced 5 minutes ago (more recent)
    Game.create!(
      home_team: @away_team,
      away_team: @home_team,
      game_time: 45.minutes.from_now,
      sport: "nba",
      external_id: "live_game_2",
      last_synced_at: 5.minutes.ago
    )

    last_sync = Game.last_live_sync
    assert_not_nil last_sync
    assert_in_delta 5.minutes.ago.to_i, last_sync.to_i, 10
  end

  test "last_upcoming_sync returns most recent sync time from upcoming window" do
    # Create an upcoming game synced 1 hour ago
    Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 24.hours.from_now,
      sport: "nba",
      external_id: "upcoming_game_1",
      last_synced_at: 1.hour.ago
    )

    last_sync = Game.last_upcoming_sync
    assert_not_nil last_sync
    assert_in_delta 1.hour.ago.to_i, last_sync.to_i, 10
  end

  test "last_distant_sync returns most recent sync time from distant window" do
    # Create a distant game synced 2 hours ago
    Game.create!(
      home_team: @home_team,
      away_team: @away_team,
      game_time: 3.days.from_now,
      sport: "nba",
      external_id: "distant_game_1",
      last_synced_at: 2.hours.ago
    )

    last_sync = Game.last_distant_sync
    assert_not_nil last_sync
    assert_in_delta 2.hours.ago.to_i, last_sync.to_i, 10
  end

  test "last sync methods return nil when no games in window" do
    # Don't create any games
    assert_nil Game.last_live_sync
    assert_nil Game.last_upcoming_sync
    assert_nil Game.last_distant_sync
  end
end
