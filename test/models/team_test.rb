require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "should have valid factory" do
    team = Team.new(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba")
    assert team.valid?
  end

  test "should have external_id attribute" do
    team = Team.new
    assert_respond_to team, :external_id
    assert_respond_to team, :external_id=
  end

  test "should have data_source attribute" do
    team = Team.new
    assert_respond_to team, :data_source
    assert_respond_to team, :data_source=
  end

  test "data_source should default to manual" do
    team = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba")
    assert_equal "manual", team.data_source
  end

  test "external_id should be unique when present" do
    Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba", external_id: "api_123")

    duplicate_team = Team.new(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "nba", external_id: "api_123")
    assert_not duplicate_team.valid?
    assert_includes duplicate_team.errors[:external_id], "has already been taken"
  end

  test "external_id can be nil" do
    team1 = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba", external_id: nil)
    team2 = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "nba", external_id: nil)

    assert team1.persisted?
    assert team2.persisted?
  end

  test "should have home_games association" do
    team = Team.new
    assert_respond_to team, :home_games
  end

  test "should have away_games association" do
    team = Team.new
    assert_respond_to team, :away_games
  end

  test "data_source can be set to api" do
    team = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "nba", data_source: "api")
    assert_equal "api", team.data_source
  end
end
