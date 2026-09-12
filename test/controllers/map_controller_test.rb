require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "the map page renders with the API url for the map controller" do
    get root_path
    assert_response :success
    assert_select "[data-controller=map][data-map-api-value]"
    assert_select ".card.welcome[hidden]", 1, "the welcome card is in the page for the controller to reveal on a first visit"
    assert_select ".card.welcome", /Help check Lusaka's new addresses/
    assert_select ".card.welcome a[href='/about']", "How it works"
    assert_select "[data-map-target=card][hidden]"
  end

  test "styleguide renders" do
    get styleguide_path
    assert_response :success
    assert_select ".display", "LS33 9XX 17"
  end
end
