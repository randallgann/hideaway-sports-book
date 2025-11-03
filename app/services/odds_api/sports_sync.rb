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

    attr_reader :regions, :markets

    def initialize(regions: DEFAULT_REGIONS, markets: DEFAULT_MARKETS)
      @regions = regions
      @markets = markets
      @client = Client.new
      @importer = GameImporter.new
    end

    # Sync odds for a single sport
    # @param sport [String] Sport key (e.g., "basketball_nba")
    # @return [Hash] Result hash with statistics
    def sync_sport(sport)
      begin
        events = @client.fetch_odds(sport, regions: @regions, markets: @markets)
        import_result = @importer.import_events(events)

        {
          success: true,
          sport: sport,
          games_created: import_result[:games_created],
          games_updated: import_result[:games_updated],
          synced_at: Time.current
        }
      rescue => e
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
      results = {
        sports_synced: 0,
        total_games_created: 0,
        total_games_updated: 0,
        errors: [],
        synced_at: Time.current
      }

      sports.each do |sport|
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
      end

      results
    end
  end
end
