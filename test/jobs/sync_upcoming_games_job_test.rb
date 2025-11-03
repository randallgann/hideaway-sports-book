require "test_helper"

class SyncUpcomingGamesJobTest < ActiveJob::TestCase
  test "job enqueues successfully" do
    assert_enqueued_with(job: SyncUpcomingGamesJob) do
      SyncUpcomingGamesJob.perform_later
    end
  end

  test "job is assigned to default queue" do
    assert_equal "default", SyncUpcomingGamesJob.new.queue_name
  end

  test "does nothing when no upcoming games exist" do
    # Ensure no games exist in upcoming window
    Game.destroy_all

    assert_nothing_raised do
      SyncUpcomingGamesJob.perform_now
    end
  end

  test "syncs sports with upcoming games" do
    # Create teams
    team_home = Team.create!(
      name: "Cowboys",
      city: "Dallas",
      sport: "americanfootball_nfl",
      external_id: "cowboys_test"
    )
    team_away = Team.create!(
      name: "Eagles",
      city: "Philadelphia",
      sport: "americanfootball_nfl",
      external_id: "eagles_test"
    )

    # Create a game in the upcoming window (24 hours from now)
    Game.create!(
      home_team: team_home,
      away_team: team_away,
      game_time: 24.hours.from_now,
      sport: "americanfootball_nfl",
      external_id: "test_game_456",
      data_source: "the_odds_api"
    )

    # Mock the OddsApi::SportsSync to avoid actual API calls
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync_sport, { success: true, games_updated: 1 }, ["americanfootball_nfl"]

    OddsApi::SportsSync.stub :new, mock_syncer do
      assert_nothing_raised do
        SyncUpcomingGamesJob.perform_now
      end
    end

    mock_syncer.verify
  end
end
