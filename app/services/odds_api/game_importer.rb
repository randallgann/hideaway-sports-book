module OddsApi
  class GameImporter
    def initialize
      @team_matcher = TeamMatcher.new
    end

    # Import a single event from the API
    # @param event_data [Hash] Event data from The Odds API
    # @param track_stats [Boolean] Whether to track creation/update stats
    # @return [Game, Hash] The game and optionally stats hash
    def import_event(event_data, track_stats: false)
      game, was_new = find_or_create_game(event_data)
      update_game_details(game, event_data)
      import_betting_lines(game, event_data["bookmakers"] || [])
      game.update!(last_synced_at: Time.current)

      if track_stats
        return game, { created: was_new, updated: !was_new }
      else
        game
      end
    end

    # Import multiple events in batch
    # @param events [Array<Hash>] Array of event data from The Odds API
    # @return [Hash] Statistics about the import
    def import_events(events)
      stats = { games_created: 0, games_updated: 0, errors: [] }

      events.each do |event_data|
        begin
          game, event_stats = import_event(event_data, track_stats: true)
          stats[:games_created] += 1 if event_stats[:created]
          stats[:games_updated] += 1 if event_stats[:updated]
        rescue => e
          stats[:errors] << { event_id: event_data["id"], error: e.message }
        end
      end

      stats
    end

    private

    def find_or_create_game(event_data)
      external_id = event_data["id"]
      sport = event_data["sport_key"]

      # Try to find existing game by external_id
      game = Game.find_by(external_id: external_id)

      if game
        [game, false] # existing game
      else
        # Create new game
        new_game = Game.new(
          external_id: external_id,
          sport: sport,
          data_source: "the_odds_api",
          status: "scheduled"
        )
        [new_game, true] # new game
      end
    end

    def update_game_details(game, event_data)
      home_team = @team_matcher.find_or_create_team(
        event_data["home_team"],
        event_data["sport_key"],
        external_id: nil # Teams don't have external IDs in this API
      )

      away_team = @team_matcher.find_or_create_team(
        event_data["away_team"],
        event_data["sport_key"],
        external_id: nil
      )

      game.assign_attributes(
        home_team: home_team,
        away_team: away_team,
        game_time: Time.parse(event_data["commence_time"]),
        sport: event_data["sport_key"]
      )

      game.save!
    end

    def import_betting_lines(game, bookmakers)
      return if bookmakers.empty?

      # Extract and aggregate odds by market type
      aggregated_odds = aggregate_odds_by_market(bookmakers, game)

      # Create or update betting lines for each market
      aggregated_odds.each do |market_key, odds_data|
        create_or_update_betting_line(game, market_key, odds_data)
      end
    end

    def aggregate_odds_by_market(bookmakers, game)
      markets_data = {}

      bookmakers.each do |bookmaker|
        next unless bookmaker["markets"]

        bookmaker["markets"].each do |market|
          market_key = market["key"]
          markets_data[market_key] ||= []
          markets_data[market_key] << parse_market_outcomes(market, game)
        end
      end

      # Average the odds from all bookmakers
      aggregated = {}
      markets_data.each do |market_key, odds_array|
        aggregated[market_key] = average_odds(odds_array)
      end

      aggregated
    end

    def parse_market_outcomes(market, game)
      outcomes = market["outcomes"]
      market_key = market["key"]

      case market_key
      when "h2h"
        parse_h2h_outcomes(outcomes, game)
      when "spreads"
        parse_spreads_outcomes(outcomes, game)
      when "totals"
        parse_totals_outcomes(outcomes)
      else
        {}
      end
    end

    def parse_h2h_outcomes(outcomes, game)
      home_outcome = outcomes.find { |o| normalize_team_name(o["name"]) == normalize_team_name(game.home_team.name) ||
                                          normalize_team_name(o["name"]).include?(normalize_team_name(game.home_team.name)) }
      away_outcome = outcomes.find { |o| normalize_team_name(o["name"]) == normalize_team_name(game.away_team.name) ||
                                          normalize_team_name(o["name"]).include?(normalize_team_name(game.away_team.name)) }

      home_outcome ||= outcomes.first
      away_outcome ||= outcomes.last

      {
        home_odds: home_outcome["price"].to_f,
        away_odds: away_outcome["price"].to_f
      }
    end

    def parse_spreads_outcomes(outcomes, game)
      home_outcome = outcomes.find { |o| normalize_team_name(o["name"]) == normalize_team_name(game.home_team.name) ||
                                          normalize_team_name(o["name"]).include?(normalize_team_name(game.home_team.name)) }
      away_outcome = outcomes.find { |o| normalize_team_name(o["name"]) == normalize_team_name(game.away_team.name) ||
                                          normalize_team_name(o["name"]).include?(normalize_team_name(game.away_team.name)) }

      home_outcome ||= outcomes.first
      away_outcome ||= outcomes.last

      {
        spread: home_outcome["point"].to_f,
        home_odds: home_outcome["price"].to_f,
        away_odds: away_outcome["price"].to_f
      }
    end

    def parse_totals_outcomes(outcomes)
      over_outcome = outcomes.find { |o| o["name"].to_s.downcase == "over" }
      under_outcome = outcomes.find { |o| o["name"].to_s.downcase == "under" }

      over_outcome ||= outcomes.first
      under_outcome ||= outcomes.last

      {
        total: over_outcome["point"].to_f,
        over_odds: over_outcome["price"].to_f,
        under_odds: under_outcome["price"].to_f
      }
    end

    def average_odds(odds_array)
      return {} if odds_array.empty?

      # Get all keys from the first hash
      keys = odds_array.first.keys
      averaged = {}

      keys.each do |key|
        values = odds_array.map { |odds| odds[key] }.compact
        averaged[key] = values.sum / values.length.to_f
      end

      averaged
    end

    def create_or_update_betting_line(game, market_key, odds_data)
      line_type = map_market_to_line_type(market_key)
      return unless line_type

      line = game.betting_lines.find_or_initialize_by(line_type: line_type)

      case line_type
      when "moneyline"
        line.assign_attributes(
          home_odds: odds_data[:home_odds].round(2),
          away_odds: odds_data[:away_odds].round(2)
        )
      when "spread"
        line.assign_attributes(
          spread: odds_data[:spread].round(2),
          home_odds: odds_data[:home_odds].round(2),
          away_odds: odds_data[:away_odds].round(2)
        )
      when "over_under"
        line.assign_attributes(
          total: odds_data[:total].round(2),
          over_odds: odds_data[:over_odds].round(2),
          under_odds: odds_data[:under_odds].round(2)
        )
      end

      line.save!
    end

    def map_market_to_line_type(market_key)
      case market_key
      when "h2h" then "moneyline"
      when "spreads" then "spread"
      when "totals" then "over_under"
      else nil
      end
    end

    def normalize_team_name(name)
      return "" if name.nil?
      name.to_s.downcase.strip.gsub(/[^a-z0-9\s]/, "")
    end
  end
end
