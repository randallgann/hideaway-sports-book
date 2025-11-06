require "test_helper"
require "ostruct"

class UserTest < ActiveSupport::TestCase
  test "valid user with email and password" do
    user = User.new(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid without password" do
    user = User.new(username: "testuser", email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "username must be unique if provided" do
    User.create!(
      username: "testuser",
      email: "user1@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    duplicate_user = User.new(
      username: "testuser",
      email: "user2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:username], "has already been taken"
  end

  test "email must be unique" do
    User.create!(
      username: "user1",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    duplicate_email_user = User.new(
      username: "user2",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate_email_user.valid?
    assert_includes duplicate_email_user.errors[:email], "has already been taken"
  end

  test "username can be nil for OAuth users" do
    user = User.new(
      email: "oauth@example.com",
      password: "password123",
      password_confirmation: "password123",
      provider: "google_oauth2",
      uid: "12345"
    )
    assert user.valid?
  end

  test "has_one bankroll association" do
    user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_respond_to user, :bankroll
  end

  test "creates bankroll automatically on user creation" do
    user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.bankroll.present?
    assert_instance_of Bankroll, user.bankroll
  end

  test "bankroll is destroyed when user is destroyed" do
    user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    bankroll_id = user.bankroll.id

    user.destroy

    assert_nil Bankroll.find_by(id: bankroll_id)
  end

  test "identifier returns username when present" do
    user = User.new(
      username: "testuser",
      email: "test@example.com",
      password: "password123"
    )

    assert_equal "testuser", user.identifier
  end

  test "identifier returns email when username is nil" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      provider: "google_oauth2",
      uid: "12345"
    )

    assert_equal "test@example.com", user.identifier
  end

  test "bankroll has correct default values" do
    user = User.create!(
      username: "testuser",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    bankroll = user.bankroll

    assert_equal 0.0, bankroll.available_balance
    assert_equal 0.0, bankroll.locked_balance
    assert_equal 'USD', bankroll.currency
    assert_equal 'paper_trading', bankroll.payment_processor
  end

  test "from_omniauth creates new user with OAuth data" do
    auth = OpenStruct.new(
      provider: 'google_oauth2',
      uid: '12345',
      info: OpenStruct.new(
        email: 'oauth@example.com',
        name: 'Test User',
        nickname: 'testuser'
      )
    )

    user = User.from_omniauth(auth)

    assert user.persisted?
    assert_equal 'google_oauth2', user.provider
    assert_equal '12345', user.uid
    assert_equal 'oauth@example.com', user.email
    assert_equal 'Test User', user.name
    assert_equal 'testuser', user.username
  end

  test "from_omniauth finds existing user" do
    existing_user = User.create!(
      provider: 'google_oauth2',
      uid: '12345',
      email: 'existing@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )

    auth = OpenStruct.new(
      provider: 'google_oauth2',
      uid: '12345',
      info: OpenStruct.new(email: 'newemail@example.com')
    )

    user = User.from_omniauth(auth)

    assert_equal existing_user.id, user.id
    assert_equal 'existing@example.com', user.email # Should not update
  end
end
