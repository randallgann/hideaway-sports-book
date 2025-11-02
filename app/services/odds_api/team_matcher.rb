module OddsApi
  class TeamMatcher
    # Find or create a team based on name and sport
    # @param team_name [String] The team name from the API
    # @param sport [String] The sport key (e.g., "basketball_nba")
    # @param external_id [String, nil] Optional external API ID
    # @return [Team] The matched or newly created team
    def find_or_create_team(team_name, sport, external_id: nil)
      # First try to find by external_id if provided
      if external_id.present?
        team = Team.find_by(external_id: external_id, sport: sport)
        return team if team
      end

      # Try to find by fuzzy name match
      team = find_by_name(team_name, sport)

      if team
        # Update the team with external_id and data_source if not already set
        update_team_metadata(team, external_id)
        team
      else
        # Create new team
        create_team(team_name, sport, external_id)
      end
    end

    private

    def find_by_name(team_name, sport)
      # Normalize the search term
      normalized_name = normalize_name(team_name)

      # Try exact match first
      teams = Team.where(sport: sport)

      # Find teams where the normalized full name matches
      teams.find do |team|
        full_name = "#{team.city} #{team.name}".strip
        normalize_name(full_name) == normalized_name ||
          normalize_name(team.name) == normalized_name ||
          normalized_name.include?(normalize_name(team.name)) ||
          normalize_name(full_name).include?(normalized_name)
      end
    end

    def normalize_name(name)
      return "" if name.nil?
      name.to_s.downcase.strip.gsub(/[^a-z0-9\s]/, "")
    end

    def update_team_metadata(team, external_id)
      updates = {}
      updates[:external_id] = external_id if external_id.present? && team.external_id.nil?
      updates[:data_source] = "api" if team.data_source == "manual"

      team.update(updates) if updates.any?
    end

    def create_team(team_name, sport, external_id)
      Team.create!(
        name: team_name,
        city: extract_city(team_name),
        abbreviation: generate_abbreviation(team_name),
        sport: sport,
        external_id: external_id,
        data_source: "api"
      )
    end

    def extract_city(team_name)
      # Simple city extraction: assume first word(s) before the last word is the city
      # e.g., "Los Angeles Lakers" -> "Los Angeles"
      # "Lakers" -> ""
      parts = team_name.split
      return "" if parts.length <= 1

      parts[0...-1].join(" ")
    end

    def generate_abbreviation(team_name)
      # Generate a simple abbreviation from the team name
      # Take first 3 letters of the last word (team nickname)
      parts = team_name.split
      last_word = parts.last || team_name
      last_word[0..2].upcase
    end
  end
end
