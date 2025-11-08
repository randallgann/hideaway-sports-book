class BettingLine < ApplicationRecord
  belongs_to :game
  has_many :bets, dependent: :restrict_with_error
end
