module OddsApi
  class SportsSync
    DEFAULT_SPORTS = [
      "basketball_nba",
      "basketball_ncaab",
      "americanfootball_nfl",
      "americanfootball_ncaaf"
    ].freeze

    DEFAULT_REGIONS = ["us", "uk", "eu"].freeze
    DEFAULT_MARKETS = ["h2h", "spreads", "totals"].freeze
    DEFAULT_REQUEST_DELAY = 2 # seconds between API requests to avoid rate limiting

    attr_reader :regions, :markets, :request_delay

    def initialize(regions: DEFAULT_REGIONS, markets: DEFAULT_MARKETS, request_delay: DEFAULT_REQUEST_DELAY)
      @regions = regions
      @markets = markets
      @request_delay = request_delay
      @client = Client.new
      @importer = GameImporter.new
    end

    # Sync odds for a single sport
    # @param sport [String] Sport key (e.g., "basketball_nba")
    # @return [Hash] Result hash with statistics
    def sync_sport(sport)
      max_retries = 3
      retry_count = 0

      begin
        Rails.logger.info("SportsSync: Starting sync for #{sport}")
        events = @client.fetch_odds(sport, regions: @regions, markets: @markets)
        import_result = @importer.import_events(events)

        Rails.logger.info("SportsSync: Completed sync for #{sport} - Created: #{import_result[:games_created]}, Updated: #{import_result[:games_updated]}")

        if import_result[:errors].any?
          Rails.logger.warn("SportsSync: #{import_result[:errors].length} errors during #{sport} import")
        end

        {
          success: true,
          sport: sport,
          games_created: import_result[:games_created],
          games_updated: import_result[:games_updated],
          synced_at: Time.current
        }
      rescue OddsApi::Client::RateLimitError => e
        retry_count += 1
        if retry_count <= max_retries
          wait_time = 2 ** retry_count # Exponential backoff: 2, 4, 8 seconds
          Rails.logger.warn("SportsSync: Rate limit hit for #{sport}, retrying in #{wait_time} seconds (attempt #{retry_count}/#{max_retries})")
          sleep(wait_time)
          retry
        else
          Rails.logger.error("SportsSync: Failed to sync #{sport} after #{max_retries} retries - #{e.class}: #{e.message}")
          {
            success: false,
            sport: sport,
            error: e.message,
            synced_at: Time.current
          }
        end
      rescue => e
        Rails.logger.error("SportsSync: Failed to sync #{sport} - #{e.class}: #{e.message}")
        {
          success: false,
          sport: sport,
          error: e.message,
          synced_at: Time.current
        }
      end
    end

    # Sync odds for multiple sports
    # @param sports [Array<String>] Array of sport keys, defaults to DEFAULT_SPORTS
    # @return [Hash] Aggregated results
    def sync_all(sports = DEFAULT_SPORTS)
      Rails.logger.info("SportsSync: Starting sync_all for #{sports.length} sports: #{sports.join(', ')}")

      results = {
        sports_synced: 0,
        total_games_created: 0,
        total_games_updated: 0,
        errors: [],
        synced_at: Time.current
      }

      sports.each_with_index do |sport, index|
        result = sync_sport(sport)

        if result[:success]
          results[:sports_synced] += 1
          results[:total_games_created] += result[:games_created]
          results[:total_games_updated] += result[:games_updated]
        else
          results[:errors] << {
            sport: sport,
            error: result[:error]
          }
        end

        # Add delay between requests to avoid rate limiting (except after the last sport)
        if index < sports.length - 1
          Rails.logger.info("SportsSync: Waiting #{@request_delay} seconds before next sport to avoid rate limiting")
          sleep(@request_delay)
        end
      end

      Rails.logger.info("SportsSync: sync_all completed - Sports: #{results[:sports_synced]}/#{sports.length}, Created: #{results[:total_games_created]}, Updated: #{results[:total_games_updated]}, Errors: #{results[:errors].length}")

      results
    end
  end
end
