class Team < ApplicationRecord
  has_many :home_games, class_name: 'Game', foreign_key: 'home_team_id'
  has_many :away_games, class_name: 'Game', foreign_key: 'away_team_id'

  validates :external_id, uniqueness: true, allow_nil: true
end
