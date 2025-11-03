class SyncUpcomingGamesJob < ApplicationJob
  queue_as :default

  # Retry on errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info("Starting upcoming games sync (1-48 hours window)")

    # Get all games in the upcoming window that came from the API
    upcoming_games = Game.from_api.upcoming_window

    if upcoming_games.empty?
      Rails.logger.info("No upcoming games to sync")
      return
    end

    Rails.logger.info("Found #{upcoming_games.count} upcoming games to sync")

    # Get unique sport keys from upcoming games
    sports = upcoming_games.pluck(:sport).uniq

    # Sync each sport
    syncer = OddsApi::SportsSync.new
    total_updated = 0

    sports.each do |sport|
      Rails.logger.info("Syncing upcoming #{sport} games")
      result = syncer.sync_sport(sport)

      if result[:success]
        total_updated += result[:games_updated]
        Rails.logger.info("Synced #{result[:games_updated]} #{sport} games")
      else
        Rails.logger.error("Failed to sync #{sport}: #{result[:error]}")
      end
    end

    Rails.logger.info("Upcoming games sync completed: #{total_updated} games updated")
  end
end
