require "application_system_test_case"

class ContributeTest < ApplicationSystemTestCase
  test "confirming an address from its card and finding it under mine" do
    visit new_contribution_path(kind: "confirm_address", building_id: buildings(:two).ingest_id)
    assert_selector "h1", text: "LS1 1CC 2"
    tap "Send"

    assert_text "Thank you"
    assert_selector ".display", text: "LS1 1CC 2"

    click_link "All my contributions"
    assert_selector ".list li", count: 1
    assert_selector ".list strong", text: "LS1 1CC 2"
  end

  test "disputing an address asks for a reason before it saves" do
    visit new_contribution_path(kind: "dispute_address", building_id: buildings(:one).ingest_id)
    tap "Send"
    assert_selector ".flash.is-error", text: "needs a reason"

    choose "The number is wrong"
    tap "Send"
    assert_text "Thank you"
  end
end
