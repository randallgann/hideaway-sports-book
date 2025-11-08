class BetsController < ApplicationController
  before_action :authenticate_user!

  def create
    @game = Game.find(params[:game_id])
    @betting_line = @game.betting_lines.find(params[:betting_line_id])

    # Validate game hasn't started
    if @game.game_time < Time.current
      render json: {
        success: false,
        message: "Cannot bet on game that has already started"
      }, status: :unprocessable_entity
      return
    end

    # Build bet with provided params
    @bet = current_user.bets.new(
      game: @game,
      betting_line: @betting_line,
      selection: params[:selection],
      amount: params[:amount]
    )

    # The before_create callbacks will:
    # - snapshot_odds (sets odds_at_placement and line_value_at_placement)
    # - calculate_potential_payout
    # - populate_metadata

    # Attempt to place bet (locks funds) within a transaction
    ActiveRecord::Base.transaction do
      # Validate the bet first (this triggers all validations)
      unless @bet.valid?
        render json: {
          success: false,
          message: @bet.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end

      # Lock funds in bankroll BEFORE saving bet
      # Note: We need to generate a temporary ID or use a different approach
      # Since we need the bet.id for the reference, we'll save first then lock
      # But we need to handle this in a transaction to ensure atomicity

      # Actually, let's restructure: save the bet first, then lock funds
      # If locking fails, we rollback the bet creation
      if @bet.save
        # Now lock the funds
        result = current_user.bankroll.lock_funds_for_bet(@bet.amount, @bet.id)

        unless result[:success]
          # Locking failed - rollback bet creation
          render json: {
            success: false,
            message: result[:message]
          }, status: :unprocessable_entity
          raise ActiveRecord::Rollback
        end

        # Success!
        render json: {
          success: true,
          message: "Bet placed successfully!",
          bet: {
            id: @bet.id,
            amount: @bet.amount,
            potential_payout: @bet.potential_payout,
            selection: @bet.selection,
            odds: @bet.odds_at_placement
          }
        }
      else
        # Bet save failed
        render json: {
          success: false,
          message: @bet.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
        raise ActiveRecord::Rollback
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: {
      success: false,
      message: "Game or betting line not found"
    }, status: :not_found
  end
end
