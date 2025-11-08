class BetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bet, only: [:show, :cancel]

  def index
    @pending_bets = current_user.bets.pending
                                .includes(game: [:home_team, :away_team], betting_line: :game)
                                .order(created_at: :desc)

    @settled_bets = current_user.bets.settled
                                .includes(game: [:home_team, :away_team], betting_line: :game)
                                .order(settled_at: :desc)
                                .limit(50)
  end

  def show
    # @bet set by before_action
  end

  def cancel
    # Validate bet is still pending
    unless @bet.status == 'pending'
      redirect_to bets_path, alert: "Can only cancel pending bets" and return
    end

    # Validate game hasn't started
    if @bet.game.game_time < Time.current
      redirect_to bet_path(@bet), alert: "Cannot cancel bet after game has started" and return
    end

    # Unlock funds in bankroll
    result = current_user.bankroll.cancel_bet(@bet.id, @bet.amount)

    if result[:success]
      @bet.update!(status: 'canceled')
      redirect_to bets_path, notice: "Bet canceled successfully - funds returned to your account"
    else
      redirect_to bet_path(@bet), alert: result[:message]
    end
  end

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

  private

  def set_bet
    @bet = current_user.bets.find(params[:id])
  end
end
