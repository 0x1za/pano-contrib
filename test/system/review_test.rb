require "application_system_test_case"

class ReviewTest < ApplicationSystemTestCase
  test "a moderator works the queue from the keyboard" do
    visit new_session_path
    fill_in "Email", with: users(:moderator).email_address
    fill_in "Password", with: "password"
    tap "Sign in"
    assert_current_path root_path

    visit review_path
    assert_selector ".queue-item", count: 2
    assert_selector ".queue-item.is-current .eyebrow", text: /district is called something else/i

    press "j"
    assert_selector ".queue-item.is-current .eyebrow", text: /i live here/i

    press "a"
    assert_text "Accepted LS1 1CC 1"
    assert_selector ".queue-item", count: 1
    assert contributions(:phone_confirms_one).reload.status_accepted?
  end

  test "a visitor votes on a place's pending name from the place page" do
    visit place_path("LS1")
    assert_selector ".eyebrow", text: /waiting for votes/i
    tap "Agree"
    assert_text "Thanks, your vote is in"
    assert_text "1 agree · 0 disagree"
    assert_no_button "Agree"
  end
end
