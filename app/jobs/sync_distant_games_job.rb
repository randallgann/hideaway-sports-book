class SyncDistantGamesJob < ApplicationJob
  queue_as :background

  # Retry on errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    execution_time = Time.current
    Rails.logger.info("Starting distant games sync (48+ hours window)")

    begin
      # Get all games in the distant window that came from the API
      distant_games = Game.from_api.distant_window

      if distant_games.empty?
        Rails.logger.info("No distant games to sync")
        JobExecution.record(self.class.name, executed_at: execution_time)
        return
      end

      Rails.logger.info("Found #{distant_games.count} distant games to sync")

      # Get unique sport keys from distant games
      sports = distant_games.pluck(:sport).uniq

      # Sync each sport
      syncer = OddsApi::SportsSync.new
      total_updated = 0

      sports.each do |sport|
        Rails.logger.info("Syncing distant #{sport} games")
        result = syncer.sync_sport(sport)

        if result[:success]
          total_updated += result[:games_updated]
          Rails.logger.info("Synced #{result[:games_updated]} #{sport} games")
        else
          Rails.logger.error("Failed to sync #{sport}: #{result[:error]}")
        end
      end

      Rails.logger.info("Distant games sync completed: #{total_updated} games updated")
      JobExecution.record(self.class.name, executed_at: execution_time)
    rescue => e
      Rails.logger.error("Distant games sync failed: #{e.message}")
      JobExecution.record(self.class.name, status: 'failed', executed_at: execution_time)
      raise
    end
  end
end
