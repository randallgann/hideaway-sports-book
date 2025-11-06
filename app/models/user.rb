class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2, :github]

  # Allow blank email for OAuth users
  validates :email, presence: true, if: -> { provider.blank? }

  # Create or find user from OmniAuth data
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email || "#{auth.provider}-#{auth.uid}@example.com"
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name
      user.username = auth.info.nickname || auth.info.name&.parameterize
    end
  has_one :bankroll, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :email, uniqueness: true, allow_nil: true

  # Callback to create bankroll when user is created
  after_create :create_default_bankroll

  # Human-readable identifier (username or email)
  def identifier
    username || email
  end

  private

  def create_default_bankroll
    create_bankroll!(currency: 'USD')
  end
end
