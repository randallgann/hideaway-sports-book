class User < ApplicationRecord
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
