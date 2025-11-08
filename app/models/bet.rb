class Bet < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :game
  belongs_to :betting_line, counter_cache: true

  # Serialization
  serialize :metadata, coder: JSON

  # Constants
  SELECTIONS = %w[home away over under].freeze
  STATUSES = %w[pending won lost push canceled].freeze

  # Validations
  validates :selection, inclusion: { in: SELECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :amount, numericality: {
    greater_than_or_equal_to: 5.00,
    message: "must be at least $5.00"
  }
  validates :odds_at_placement, presence: true

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :settled, -> { where(status: %w[won lost push]) }
  scope :won, -> { where(status: 'won') }
  scope :lost, -> { where(status: 'lost') }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_game, ->(game_id) { where(game_id: game_id) }
  scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

  # Callbacks
  before_create :snapshot_odds
  before_create :calculate_potential_payout
  before_create :populate_metadata

  # Calculate potential payout from American odds
  def calculate_potential_payout
    if odds_at_placement > 0
      # Underdog: +130 means win $130 on $100 bet
      profit = amount * (odds_at_placement / 100.0)
    else
      # Favorite: -150 means bet $150 to win $100
      profit = amount * (100.0 / odds_at_placement.abs)
    end

    self.potential_payout = amount + profit  # Return stake + winnings
  end

  # Store game/team info for historical display
  def populate_metadata
    self.metadata = {
      game_time: game.game_time,
      sport: game.sport,
      home_team: game.home_team.name,
      away_team: game.away_team.name,
      home_team_abbr: game.home_team.abbreviation,
      away_team_abbr: game.away_team.abbreviation,
      line_type: betting_line.line_type
    }
  end

  # Snapshot odds at placement time
  def snapshot_odds
    case betting_line.line_type
    when 'moneyline'
      self.odds_at_placement = selection == 'home' ? betting_line.home_odds : betting_line.away_odds
    when 'spread'
      self.odds_at_placement = selection == 'home' ? betting_line.home_odds : betting_line.away_odds
      self.line_value_at_placement = betting_line.spread
    when 'over_under'
      self.odds_at_placement = selection == 'over' ? betting_line.over_odds : betting_line.under_odds
      self.line_value_at_placement = betting_line.total
    end
  end

  # Determine bet result based on final score
  def determine_result
    return nil unless game.status == 'completed'
    return nil unless game.home_score && game.away_score

    case betting_line.line_type
    when 'moneyline'
      check_moneyline_result
    when 'spread'
      check_spread_result
    when 'over_under'
      check_over_under_result
    end
  end

  # Settle bet and update bankroll
  def settle!
    result = determine_result
    return false unless result

    transaction do
      case result
      when 'won'
        settle_win
      when 'lost'
        settle_loss
      when 'push'
        settle_push
      end
    end
  end

  private

  def check_moneyline_result
    return 'push' if game.home_score == game.away_score

    winner = game.home_score > game.away_score ? 'home' : 'away'
    selection == winner ? 'won' : 'lost'
  end

  def check_spread_result
    # Apply spread to selected team's score
    if selection == 'home'
      adjusted_score = game.home_score + line_value_at_placement
      result_score = game.away_score
    else
      adjusted_score = game.away_score - line_value_at_placement
      result_score = game.home_score
    end

    # Check if bet covered the spread
    return 'push' if adjusted_score == result_score
    adjusted_score > result_score ? 'won' : 'lost'
  end

  def check_over_under_result
    total_points = game.home_score + game.away_score

    return 'push' if total_points == line_value_at_placement

    if selection == 'over'
      total_points > line_value_at_placement ? 'won' : 'lost'
    else
      total_points < line_value_at_placement ? 'won' : 'lost'
    end
  end

  def settle_win
    result = user.bankroll.settle_bet_win(id, amount, potential_payout)
    if result[:success]
      update!(
        status: 'won',
        actual_payout: potential_payout,
        settled_at: Time.current,
        settlement_notes: "Bet won - payout: #{potential_payout}"
      )
    end
  end

  def settle_loss
    result = user.bankroll.settle_bet_loss(id, amount)
    if result[:success]
      update!(
        status: 'lost',
        actual_payout: 0,
        settled_at: Time.current,
        settlement_notes: "Bet lost"
      )
    end
  end

  def settle_push
    result = user.bankroll.settle_bet_push(id, amount)
    if result[:success]
      update!(
        status: 'push',
        actual_payout: amount,
        settled_at: Time.current,
        settlement_notes: "Push - stake returned"
      )
    end
  end
end
