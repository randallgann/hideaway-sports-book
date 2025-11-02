class GamesController < ApplicationController
  def index
    # Fetch all games with their associated teams and betting lines
    # .includes() prevents N+1 queries by loading associations in advance
    # .order() sorts games by time (earliest first)
    @games = Game.includes(:home_team, :away_team, :betting_lines)
                 .order(:game_time)
  end
end
