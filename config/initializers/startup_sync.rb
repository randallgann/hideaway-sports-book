# Trigger an odds sync when the application starts
# This ensures fresh data is available immediately after deployment or restart

Rails.application.config.after_initialize do
  # Only run in development and production environments
  # Skip for console, rake tasks, and test environment
  next unless Rails.env.development? || Rails.env.production?
  next if defined?(Rails::Console)
  next if File.basename($0) == 'rake'

  # Queue the sync job to run asynchronously with a 10 second delay
  # This prevents conflicts with recurring tasks that may also be starting
  Rails.logger.info("Startup: Queuing initial odds sync job (delayed 10 seconds)")

  begin
    SyncAllSportsJob.set(wait: 10.seconds).perform_later
    Rails.logger.info("Startup: Initial odds sync job queued successfully")
  rescue => e
    Rails.logger.error("Startup: Failed to queue initial odds sync - #{e.class}: #{e.message}")
  end
end
