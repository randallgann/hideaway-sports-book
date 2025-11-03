require "test_helper"

class SyncLiveGamesJobTest < ActiveJob::TestCase
  test "job enqueues successfully" do
    assert_enqueued_with(job: SyncLiveGamesJob) do
      SyncLiveGamesJob.perform_later
    end
  end

  test "job is assigned to critical queue" do
    assert_equal "critical", SyncLiveGamesJob.new.queue_name
  end

  test "does nothing when no live games exist" do
    # Ensure no games exist in live window
    Game.destroy_all

    assert_nothing_raised do
      SyncLiveGamesJob.perform_now
    end
  end

  test "syncs sports with live games" do
    # Create a team and a live game
    team_home = Team.create!(
      name: "Lakers",
      city: "Los Angeles",
      sport: "basketball_nba",
      external_id: "lakers_test"
    )
    team_away = Team.create!(
      name: "Warriors",
      city: "Golden State",
      sport: "basketball_nba",
      external_id: "warriors_test"
    )

    # Create a game in the live window (30 minutes from now)
    Game.create!(
      home_team: team_home,
      away_team: team_away,
      game_time: 30.minutes.from_now,
      sport: "basketball_nba",
      external_id: "test_game_123",
      data_source: "the_odds_api"
    )

    # Mock the OddsApi::SportsSync to avoid actual API calls
    mock_syncer = Minitest::Mock.new
    mock_syncer.expect :sync_sport, { success: true, games_updated: 1 }, ["basketball_nba"]

    OddsApi::SportsSync.stub :new, mock_syncer do
      assert_nothing_raised do
        SyncLiveGamesJob.perform_now
      end
    end

    mock_syncer.verify
  end
end
