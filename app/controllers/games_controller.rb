class GamesController < ApplicationController
  def index
    # Fetch games from API only (exclude seed data)
    # .includes() prevents N+1 queries by loading associations in advance
    # .where() filters to only API-sourced games and upcoming/live games
    # .order() sorts games by time (earliest first)
    # .group_by() organizes games by sport for collapsible sections
    games = Game.includes(:home_team, :away_team, :betting_lines)
                .where(data_source: "the_odds_api")
                .where("game_time >= ?", 4.hours.ago)
                .order(:game_time)

    # Group games by sport and sort sports alphabetically
    @games_by_sport = games.group_by(&:sport).sort.to_h

    # Get actual data sync times from games (not job execution times)
    # This shows when odds data was last successfully updated from the API
    @last_live_sync = Game.from_api.live_window.maximum(:last_synced_at)
    @last_upcoming_sync = Game.from_api.upcoming_window.maximum(:last_synced_at)
    @last_distant_sync = Game.from_api.distant_window.maximum(:last_synced_at)
  end
end
