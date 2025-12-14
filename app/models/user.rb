class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2, :github ]


  # Associations
  has_one :bankroll, dependent: :destroy
  has_many :bets, dependent: :destroy

  # Validations
  validates :username, uniqueness: true, allow_nil: true
  validates :email, uniqueness: true, if: -> { provider.blank? }
  validates :house, uniqueness: true, if: :house?

  # Leaderboard scopes
  scope :players, -> { where(house: false) }
  scope :on_leaderboard, -> { where(show_on_leaderboard: true) }
  scope :with_bankroll, -> { joins(:bankroll) }

  scope :leaderboard_ordered, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        "users.*",
        "(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance"
      )
      .order("total_balance DESC, users.created_at ASC")
  }

  scope :by_profit, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        "users.*",
        "(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance",
        "(bankrolls.available_balance + bankrolls.locked_balance - #{Bankroll::INITIAL_BALANCE}) AS profit"
      )
      .order("profit DESC, users.created_at ASC")
  }

  scope :by_roi, -> {
    players
      .on_leaderboard
      .with_bankroll
      .select(
        "users.*",
        "(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance",
        "((bankrolls.available_balance + bankrolls.locked_balance - #{Bankroll::INITIAL_BALANCE}) / #{Bankroll::INITIAL_BALANCE} * 100.0) AS roi"
      )
      .order("roi DESC, users.created_at ASC")
  }

  scope :by_win_rate, -> {
    players
      .on_leaderboard
      .where("bets_count > 0")
      .with_bankroll
      .select(
        "users.*",
        "(bankrolls.available_balance + bankrolls.locked_balance) AS total_balance",
        "(won_bets_count::float / bets_count * 100) AS win_rate"
      )
      .order("win_rate DESC, bets_count DESC, users.created_at ASC")
  }

  # Singleton pattern for house user
  def self.house
    find_or_create_by!(house: true) do |user|
      user.email = "house@hideaway.local"
      user.password = SecureRandom.hex(32)
      user.name = "The House"
    end
  end

  # Callback to create bankroll when user is created
  after_create :create_default_bankroll

  # Create or find user from OmniAuth data
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email || "#{auth.provider}-#{auth.uid}@example.com"
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.username = auth.info.nickname || auth.info.name&.parameterize
    end
  end

  # Human-readable identifier (username or email)
  def identifier
    username || email
  end

  # Leaderboard display name (username or "Player #ID")
  def display_name
    username.presence || "Player ##{id}"
  end

  # Profit/loss since initial balance
  def profit_loss
    return 0 unless bankroll
    bankroll.total_balance - Bankroll::INITIAL_BALANCE
  end

  # Return on investment percentage
  def roi_percentage
    return 0 if Bankroll::INITIAL_BALANCE.zero?
    (profit_loss / Bankroll::INITIAL_BALANCE * 100).round(2)
  end

  # Win rate percentage (nil if no bets)
  def win_rate_percentage
    return nil if bets_count.zero?
    (won_bets_count.to_f / bets_count * 100).round(1)
  end

  # Calculate user's rank on the leaderboard
  def leaderboard_rank
    return nil unless bankroll

    User.players
        .on_leaderboard
        .with_bankroll
        .where("(bankrolls.available_balance + bankrolls.locked_balance) > ?", bankroll.total_balance)
        .count + 1
  end

  private

  def create_default_bankroll
    create_bankroll!(
      currency: "USD",
      available_balance: Bankroll::INITIAL_BALANCE
    )
  end
end
