module BettingHelper
  # Format American odds with + prefix for positive values
  def format_odds(odds)
    return 'N/A' if odds.nil?

    odds > 0 ? "+#{odds.to_i}" : odds.to_i.to_s
  end

  # Return CSS class for odds coloring (red for favorites, green for underdogs)
  def odds_color_class(odds)
    return 'text-gray-400' if odds.nil?

    odds < 0 ? 'text-red-400' : 'text-green-400'
  end

  # Format currency values
  def format_currency(amount)
    number_to_currency(amount, precision: 2)
  end

  # Return CSS classes for bet status badges
  def bet_status_badge_class(status)
    case status
    when 'won'
      'bg-green-600 text-white'
    when 'lost'
      'bg-red-600 text-white'
    when 'push'
      'bg-gray-600 text-white'
    when 'pending'
      'bg-yellow-600 text-white'
    when 'canceled'
      'bg-gray-500 text-white'
    else
      'bg-gray-400 text-white'
    end
  end

  # Format spread value with proper sign
  def format_spread(spread)
    return 'N/A' if spread.nil?

    spread > 0 ? "+#{spread}" : spread.to_s
  end
end
