require "test_helper"

class LeaderboardControllerTest < ActionDispatch::IntegrationTest
  test "lists accounts by reputation under the name they chose, never an email" do
    users(:moderator).update!(reputation: 5)
    users(:one).update!(reputation: 3)
    get leaderboard_path
    assert_response :success
    assert_select ".board .who", /Mwila/
    assert_select ".board .who", /Anonymous contributor/, "an account without a display name is not named"
    assert_no_match(/one@example.com/, response.body)
    assert_select ".facts--row dd", minimum: 4
  end

  test "this week counts acceptances reviewed in the last seven days" do
    c = contributions(:phone_confirms_one)
    c.update!(user: users(:moderator))
    c.accept!(by: users(:admin))
    get leaderboard_path
    assert_select "section", /This week/ do
      assert_select ".board li", 1
      assert_select ".score", "1 accepted"
    end
  end

  test "a visitor sees their own badges and a nudge to sign up" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    get leaderboard_path
    assert_select ".badges .badge", Badges::ALL.size
    assert_select ".badge.is-earned", 1, "founder: any contribution against v0.1.0 counts, accepted or not"
    assert_select ".badge.is-earned .badge-name", "Founder"
    assert_select "a[href='/registration/new']", "sign up"
  end
end
