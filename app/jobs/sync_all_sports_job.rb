class SyncAllSportsJob < ApplicationJob
  queue_as :default

  # Retry on errors with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    Rails.logger.info("Starting full sync for all configured sports")

    # Sync all default sports (NBA, NCAAB, NFL, NCAAF)
    syncer = OddsApi::SportsSync.new
    result = syncer.sync_all

    Rails.logger.info("Full sync completed: #{result[:sports_synced]} sports synced")
    Rails.logger.info("Games created: #{result[:total_games_created]}")
    Rails.logger.info("Games updated: #{result[:total_games_updated]}")

    if result[:errors].any?
      Rails.logger.error("Sync errors: #{result[:errors]}")
    end

    result
  end
end
