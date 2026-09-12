require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  test "the queue is not a page for contributors or strangers" do
    get review_path
    assert_redirected_to new_session_path
    sign_in_as(users(:one))
    get review_path
    assert_response :not_found
  end

  test "a moderator sees the queue with disputes first" do
    sign_in_as(users(:moderator))
    get review_path
    assert_response :success
    assert_select ".queue-item", 2
    assert_select ".queue-item:first-child .eyebrow", /district is called something else/
    assert_select "a[href='/review']", "Review"
  end

  test "a moderator accepts with a note" do
    sign_in_as(users(:moderator))
    c = contributions(:other_disputes_district)
    patch review_decision_path(c), params: { decision: "accept", note: "Matches the council's list." }
    assert_redirected_to review_path
    c.reload
    assert c.status_accepted?
    assert_equal users(:moderator), c.reviewed_by
    assert_equal "Matches the council's list.", c.review_note
  end

  test "a moderator rejects, and a contributor cannot decide" do
    c = contributions(:phone_confirms_one)
    sign_in_as(users(:one))
    patch review_decision_path(c), params: { decision: "reject" }
    assert_response :not_found
    assert c.reload.status_pending?

    sign_in_as(users(:moderator))
    patch review_decision_path(c), params: { decision: "reject", note: "Empty plot." }
    assert c.reload.status_rejected?
  end

  test "an unknown decision changes nothing" do
    sign_in_as(users(:admin))
    c = contributions(:phone_confirms_one)
    patch review_decision_path(c), params: { decision: "maybe" }
    assert_redirected_to review_path
    assert c.reload.status_pending?
  end
end
