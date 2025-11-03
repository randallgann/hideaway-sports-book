require "test_helper"

class SyncDistantGamesJobTest < ActiveJob::TestCase
  test "job enqueues successfully" do
    assert_enqueued_with(job: SyncDistantGamesJob) do
      SyncDistantGamesJob.perform_later
    end
  end

  test "job is assigned to background queue" do
    assert_equal "background", SyncDistantGamesJob.new.queue_name
  end

  test "does nothing when no distant games exist" do
    # Ensure no games exist in distant window
    Game.destroy_all

    assert_nothing_raised do
      SyncDistantGamesJob.perform_now
    end
  end

  test "syncs sports with distant games" do
    # Create teams
    team_home = Team.create!(
      name: "Knicks",
      city: "New York",
      sport: "basketball_nba",
      external_id: "knicks_test"
    )
    team_away = Team.create!(
      name: "Celtics",
      city: "Boston",
      sport: "basketball_nba",
      external_id: "celtics_test"
    )

    # Create a game in the distant window (3 days from now)
    Game.create!(
      home_team: team_home,
      away_team: team_away,
      game_time: 3.days.from_now,
      sport: "basketball_nba",
      external_id: "test_game_789",
      data_source: "the_odds_api"
    )

    # Mock the OddsApi::SportsSync to avoid actual API calls
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync_sport, { success: true, games_updated: 1 }, ["basketball_nba"]

    OddsApi::SportsSync.stub :new, mock_syncer do
      assert_nothing_raised do
        SyncDistantGamesJob.perform_now
      end
    end

    mock_syncer.verify
  end
end
