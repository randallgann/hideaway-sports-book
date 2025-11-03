module GamesHelper
  # Formats sport key for display in UI
  # @param sport_key [String] The sport key from the database (e.g., "americanfootball_nfl")
  # @return [String] Human-readable sport name (e.g., "NFL")
  def format_sport_name(sport_key)
    case sport_key.to_s.downcase
    when "americanfootball_nfl", "nfl"
      "NFL"
    when "basketball_nba", "nba"
      "NBA"
    when "americanfootball_ncaaf", "ncaaf"
      "NCAA - Football"
    when "basketball_ncaab", "ncaab"
      "NCAA - Basketball"
    else
      sport_key.to_s.upcase
    end
  end
end
