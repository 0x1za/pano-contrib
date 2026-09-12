require "test_helper"

class VotesControllerTest < ActionDispatch::IntegrationTest
  test "a vote is recorded once per device and shows in the tally" do
    c = contributions(:other_disputes_district)
    assert_difference -> { c.votes.count }, 1 do
      post contribution_vote_path(c, stance: "agree")
    end
    assert_redirected_to contribution_path(c)
    post contribution_vote_path(c, stance: "disagree")
    assert_equal 1, c.votes.count, "the second vote from the same device is refused"
    assert_equal "Device has already voted", flash[:alert]
  end

  test "the third agreement accepts an address confirmation" do
    c = contributions(:phone_confirms_one)
    2.times { c.votes.create!(stance: :agree, device: Device.issue!.first) }
    post contribution_vote_path(c, stance: "agree")
    assert c.reload.status_accepted?
  end
end
