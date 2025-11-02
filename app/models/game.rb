class Game < ApplicationRecord
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  has_many :betting_lines, dependent: :destroy

  validates :external_id, uniqueness: true, allow_nil: true
end
