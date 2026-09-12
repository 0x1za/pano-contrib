require "application_system_test_case"

class WelcomeTest < ApplicationSystemTestCase
  test "a first visit is welcomed once, and the bar brings it back" do
    visit root_path
    assert_selector ".card.welcome", text: "Help check Lusaka's new addresses"
    tap "Got it, show me the map"
    assert_no_selector ".card.welcome"

    visit root_path
    assert_no_selector ".card.welcome", wait: 2

    execute_script("arguments[0].click()", find("button", text: "About"))
    assert_selector ".card.welcome", text: "Help check Lusaka's new addresses"
    click_link "How it works"
    assert_selector "h1", text: "What pano is"
  end
end
