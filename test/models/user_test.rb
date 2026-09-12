require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email address" do
    user = User.create!(email_address: " ONE.two@Example.COM ", password: "password")
    assert_equal "one.two@example.com", user.email_address
  end

  test "claiming a device takes its contributions and votes" do
    user = users(:two)
    device = devices(:phone)
    contributions(:other_disputes_district).votes.create!(stance: :agree, device: device)
    user.claim!(device)
    assert_equal user, device.reload.user
    assert_equal [ user.id ], device.contributions.distinct.pluck(:user_id)
    assert_equal [ user.id ], device.votes.distinct.pluck(:user_id)
  end

  test "claiming is idempotent and does not take another account's device" do
    device = devices(:phone)
    users(:one).claim!(device)
    users(:two).claim!(device)
    assert_equal users(:one), device.reload.user, "a device belongs to the first account that claimed it"
  end

  test "reviewers are moderators and admins" do
    assert users(:moderator).reviewer?
    assert users(:admin).reviewer?
    assert_not users(:one).reviewer?
  end
end
