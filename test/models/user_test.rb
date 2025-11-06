require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with username" do
    user = User.new(username: "testuser")
    assert user.valid?
  end

  test "valid user with username and email" do
    user = User.new(username: "testuser", email: "test@example.com")
    assert user.valid?
  end

  test "invalid without username" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "username must be unique" do
    User.create!(username: "testuser")
    duplicate_user = User.new(username: "testuser")

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:username], "has already been taken"
  end

  test "email must be unique if provided" do
    User.create!(username: "user1", email: "test@example.com")
    duplicate_email_user = User.new(username: "user2", email: "test@example.com")

    assert_not duplicate_email_user.valid?
    assert_includes duplicate_email_user.errors[:email], "has already been taken"
  end

  test "email can be nil" do
    user = User.create!(username: "testuser", email: nil)
    assert user.persisted?
  end

  test "multiple users can have nil email" do
    user1 = User.create!(username: "user1", email: nil)
    user2 = User.create!(username: "user2", email: nil)

    assert user1.persisted?
    assert user2.persisted?
  end

  test "has_one bankroll association" do
    user = User.create!(username: "testuser")

    assert_respond_to user, :bankroll
  end

  test "creates bankroll automatically on user creation" do
    user = User.create!(username: "testuser")

    assert user.bankroll.present?
    assert_instance_of Bankroll, user.bankroll
  end

  test "bankroll is destroyed when user is destroyed" do
    user = User.create!(username: "testuser")
    bankroll_id = user.bankroll.id

    user.destroy

    assert_nil Bankroll.find_by(id: bankroll_id)
  end

  test "identifier returns username when present" do
    user = User.new(username: "testuser", email: "test@example.com")

    assert_equal "testuser", user.identifier
  end

  test "identifier returns email when username is nil" do
    # This shouldn't happen due to validation, but test the method
    user = User.new(email: "test@example.com")
    user.save(validate: false) # Skip validation

    assert_equal "test@example.com", user.identifier
  end

  test "bankroll has correct default values" do
    user = User.create!(username: "testuser")
    bankroll = user.bankroll

    assert_equal 0.0, bankroll.available_balance
    assert_equal 0.0, bankroll.locked_balance
    assert_equal 'USD', bankroll.currency
    assert_equal 'paper_trading', bankroll.payment_processor
  end
end
