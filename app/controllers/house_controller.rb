class HouseController < ApplicationController
  # No authentication required - public access
  skip_before_action :authenticate_user!, raise: false

  def show
    @house_user = User.house
    @bankroll = @house_user.bankroll
    @recent_transactions = @bankroll.transaction_history(limit: 20)
    @stats = @bankroll.stats
  end
end
