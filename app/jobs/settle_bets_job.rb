class SettleBetsJob < ApplicationJob
  queue_as :default

  def perform
    # Find all completed games with pending bets
    game_ids = Bet.pending.distinct.pluck(:game_id)

    completed_games = Game.where(id: game_ids, status: 'completed')
                          .where.not(home_score: nil)
                          .where.not(away_score: nil)

    Rails.logger.info "SettleBetsJob: Found #{completed_games.count} completed games with pending bets"

    completed_games.find_each do |game|
      settle_game_bets(game)
    end
  end

  private

  def settle_game_bets(game)
    pending_bets = game.bets.pending

    Rails.logger.info "SettleBetsJob: Settling #{pending_bets.count} bets for game #{game.id}"

    pending_bets.find_each do |bet|
      settle_bet(bet)
    end
  end

  def settle_bet(bet)
    # Determine the result of the bet
    result = bet.determine_result

    unless result
      Rails.logger.warn "SettleBetsJob: Unable to determine result for bet #{bet.id}"
      return
    end

    # Settle the bet based on the result
    bet.settle!

    Rails.logger.info "SettleBetsJob: Bet #{bet.id} settled as #{bet.status}"
  rescue => e
    Rails.logger.error "SettleBetsJob: Failed to settle bet #{bet.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
