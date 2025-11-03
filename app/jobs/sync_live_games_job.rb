class SyncLiveGamesJob < ApplicationJob
  queue_as :critical

  # Retry on errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info("Starting live games sync (within 1 hour window)")

    # Get all games in the live window that came from the API
    live_games = Game.from_api.live_window

    if live_games.empty?
      Rails.logger.info("No live games to sync")
      return
    end

    Rails.logger.info("Found #{live_games.count} live games to sync")

    # Get unique sport keys from live games
    sports = live_games.pluck(:sport).uniq

    # Sync each sport
    syncer = OddsApi::SportsSync.new
    total_updated = 0

    sports.each do |sport|
      Rails.logger.info("Syncing live #{sport} games")
      result = syncer.sync_sport(sport)

      if result[:success]
        total_updated += result[:games_updated]
        Rails.logger.info("Synced #{result[:games_updated]} #{sport} games")
      else
        Rails.logger.error("Failed to sync #{sport}: #{result[:error]}")
      end
    end

    Rails.logger.info("Live games sync completed: #{total_updated} games updated")
  end
end
