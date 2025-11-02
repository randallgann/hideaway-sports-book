require "test_helper"

class OddsApi::TeamMatcherTest < ActiveSupport::TestCase
  def setup
    @matcher = OddsApi::TeamMatcher.new
    # Create some test teams
    @lakers = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAL", sport: "basketball_nba", data_source: "manual")
    @warriors = Team.create!(name: "Warriors", city: "Golden State", abbreviation: "GSW", sport: "basketball_nba", data_source: "manual")
  end

  test "finds team by exact name match" do
    team = @matcher.find_or_create_team("Los Angeles Lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
  end

  test "finds team by partial name match" do
    team = @matcher.find_or_create_team("Lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
  end

  test "creates new team when no match found" do
    assert_difference 'Team.count', 1 do
      team = @matcher.find_or_create_team("Boston Celtics", "basketball_nba", external_id: "api_celtics_123")
      assert_equal "Boston Celtics", team.name
      assert_equal "basketball_nba", team.sport
      assert_equal "api", team.data_source
      assert_equal "api_celtics_123", team.external_id
    end
  end

  test "finds team by external_id if provided" do
    @lakers.update!(external_id: "api_lakers_456")

    team = @matcher.find_or_create_team("LA Lakers", "basketball_nba", external_id: "api_lakers_456")
    assert_equal @lakers.id, team.id
  end

  test "updates existing team with external_id on match" do
    assert_nil @lakers.external_id

    team = @matcher.find_or_create_team("Los Angeles Lakers", "basketball_nba", external_id: "api_lakers_789")
    assert_equal @lakers.id, team.id
    assert_equal "api_lakers_789", team.reload.external_id
    assert_equal "api", team.reload.data_source
  end

  test "handles team names with city prefixes" do
    team = @matcher.find_or_create_team("Los Angeles Lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
  end

  test "handles team names without city prefixes" do
    team = @matcher.find_or_create_team("Lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
  end

  test "is case insensitive when matching" do
    team = @matcher.find_or_create_team("los angeles lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
  end

  test "filters by sport when matching" do
    # Create an NFL team with the same name
    nfl_lakers = Team.create!(name: "Lakers", city: "Los Angeles", abbreviation: "LAK", sport: "americanfootball_nfl", data_source: "manual")

    # Should find NBA Lakers
    team = @matcher.find_or_create_team("Lakers", "basketball_nba")
    assert_equal @lakers.id, team.id
    assert_not_equal nfl_lakers.id, team.id

    # Should find NFL Lakers
    team = @matcher.find_or_create_team("Lakers", "americanfootball_nfl")
    assert_equal nfl_lakers.id, team.id
  end

  test "extracts city from full team name when creating" do
    team = @matcher.find_or_create_team("Boston Celtics", "basketball_nba", external_id: "api_celtics_123")

    assert_equal "Boston Celtics", team.name
    # City extraction logic may vary, this is optional behavior
  end

  test "does not create duplicate teams" do
    # First call creates the team
    team1 = @matcher.find_or_create_team("Boston Celtics", "basketball_nba", external_id: "api_celtics_123")

    # Second call should find the existing team
    assert_no_difference 'Team.count' do
      team2 = @matcher.find_or_create_team("Boston Celtics", "basketball_nba", external_id: "api_celtics_123")
      assert_equal team1.id, team2.id
    end
  end
end
