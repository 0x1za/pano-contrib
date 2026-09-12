require "test_helper"

class VoteTest < ActiveSupport::TestCase
  test "a device votes once per contribution" do
    c = contributions(:other_disputes_district)
    assert c.votes.create(stance: :agree, device: devices(:phone)).persisted?
    dup = c.votes.create(stance: :disagree, device: devices(:phone))
    assert_includes dup.errors[:device_id], "has already voted"
  end

  test "an account votes once even from a second device" do
    c = contributions(:other_disputes_district)
    second = Device.issue!.first
    assert c.votes.create(stance: :agree, device: devices(:phone), user: users(:one)).persisted?
    again = c.votes.create(stance: :agree, device: second, user: users(:one))
    assert_includes again.errors[:user_id], "has already voted"
  end

  test "nobody votes on their own contribution" do
    c = contributions(:phone_confirms_one)
    vote = c.votes.create(stance: :agree, device: devices(:phone))
    assert_includes vote.errors[:base], "You cannot vote on your own contribution"
  end
end
