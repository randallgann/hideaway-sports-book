module LeaderboardHelper
  def rank_badge(position)
    case position
    when 1 then "🥇"
    when 2 then "🥈"
    when 3 then "🥉"
    else "##{position}"
    end
  end
end
