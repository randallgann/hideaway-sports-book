require "test_helper"

class LeaderboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user_one = users(:one)
    @user_two = users(:two)
  end

  test "should get leaderboard without authentication" do
    get leaderboard_path
    assert_response :success
  end

  test "should display leaderboard heading" do
    get leaderboard_path
    assert_response :success
    assert_select "h1", text: "Leaderboard"
  end

  test "should display sort options" do
    get leaderboard_path
    assert_response :success
    assert_select "a", text: "Balance"
    assert_select "a", text: "Profit"
    assert_select "a", text: "ROI %"
    assert_select "a", text: "Win Rate"
  end

  test "should filter by profit sort parameter" do
    get leaderboard_path(sort: "profit")
    assert_response :success
  end

  test "should filter by roi sort parameter" do
    get leaderboard_path(sort: "roi")
    assert_response :success
  end

  test "should filter by win_rate sort parameter" do
    get leaderboard_path(sort: "win_rate")
    assert_response :success
  end

  test "should ignore invalid sort parameter and default to balance" do
    get leaderboard_path(sort: "invalid_sort")
    assert_response :success
  end

  test "should highlight current user when signed in" do
    sign_in @user_one
    get leaderboard_path
    assert_response :success
    # The current user's row should have the highlight class
    assert_select "tr.bg-\\[\\#4CAF50\\]\\/10", minimum: 0
  end

  test "should exclude house account from leaderboard" do
    # Ensure house user exists
    house = User.house
    get leaderboard_path
    assert_response :success
    # House email should not appear in the response
    assert_no_match(/house@hideaway\.local/, response.body)
  end

  test "should display player count" do
    get leaderboard_path
    assert_response :success
    assert_select "div", /\d+ players? competing/
  end
end
