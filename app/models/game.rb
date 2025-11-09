class Game < ApplicationRecord
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  has_many :betting_lines, dependent: :destroy
  has_many :bets, dependent: :restrict_with_error

  validates :external_id, uniqueness: true, allow_nil: true

  # Scopes for time-based filtering
  # Live games: within 1 hour of start (including games in progress)
  scope :live_window, -> {
    where("game_time <= ? AND game_time >= ?",
          1.hour.from_now,
          4.hours.ago) # Assume games last ~4 hours max
  }

  # Upcoming games: 1-48 hours from now
  scope :upcoming_window, -> {
    where("game_time > ? AND game_time <= ?",
          1.hour.from_now,
          48.hours.from_now)
  }

  # Distant games: more than 48 hours from now
  scope :distant_window, -> {
    where("game_time > ?", 48.hours.from_now)
  }

  # Games that need syncing (have external_id from API)
  scope :from_api, -> { where.not(external_id: nil) }

  # Class methods to get last sync times for each window
  def self.last_live_sync
    from_api.live_window.maximum(:last_synced_at)
  end

  def self.last_upcoming_sync
    from_api.upcoming_window.maximum(:last_synced_at)
  end

  def self.last_distant_sync
    from_api.distant_window.maximum(:last_synced_at)
  end
end
