require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get games_url
    assert_response :success
  end

  test "index displays last sync times section" do
    get games_url
    assert_response :success
    assert_select "div", text: /Last Sync Times/
    assert_select "strong", text: /Live Games/
    assert_select "strong", text: /Upcoming/
    assert_select "strong", text: /Distant/
  end

  test "index displays sync times when games exist" do
    # Create teams
    home_team = Team.create!(
      name: "Lakers",
      city: "Los Angeles",
      sport: "basketball_nba"
    )
    away_team = Team.create!(
      name: "Warriors",
      city: "Golden State",
      sport: "basketball_nba"
    )

    # Create a synced game in the upcoming window with all required fields
    Game.create!(
      home_team: home_team,
      away_team: away_team,
      game_time: 24.hours.from_now,
      sport: "basketball_nba",
      status: "scheduled",
      external_id: "test_game",
      data_source: "the_odds_api",
      last_synced_at: 1.hour.ago
    )

    get games_url
    assert_response :success
    assert_select "div", text: /Last Sync Times/
  end
end
