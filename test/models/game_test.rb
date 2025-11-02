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
end
