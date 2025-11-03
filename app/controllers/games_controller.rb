class GamesController < ApplicationController
  def index
    # Fetch games from API only (exclude seed data)
    # .includes() prevents N+1 queries by loading associations in advance
    # .where() filters to only API-sourced games
    # .order() sorts games by time (earliest first)
    # .group_by() organizes games by sport for collapsible sections
    games = Game.includes(:home_team, :away_team, :betting_lines)
                .where(data_source: "the_odds_api")
                .order(:game_time)

    # Group games by sport and sort sports alphabetically
    @games_by_sport = games.group_by(&:sport).sort.to_h

    # Get last sync times for each window
    @last_live_sync = Game.last_live_sync
    @last_upcoming_sync = Game.last_upcoming_sync
    @last_distant_sync = Game.last_distant_sync
  end
end
