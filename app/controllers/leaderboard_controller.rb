class LeaderboardController < ApplicationController
  # No authentication required - public access
  skip_before_action :authenticate_user!, raise: false

  VALID_SORTS = %w[balance profit roi win_rate].freeze
  PER_PAGE = 25

  def show
    @sort = VALID_SORTS.include?(params[:sort]) ? params[:sort] : "balance"

    users_query = leaderboard_query_for(@sort)
    @pagy, @users = pagy(users_query, limit: PER_PAGE)

    @current_user_rank = current_user&.leaderboard_rank if user_signed_in?
    @total_players = User.players.on_leaderboard.count
  end

  private

  def leaderboard_query_for(sort)
    case sort
    when "profit"
      User.by_profit
    when "roi"
      User.by_roi
    when "win_rate"
      User.by_win_rate
    else
      User.leaderboard_ordered
    end.includes(:bankroll)
  end
end
