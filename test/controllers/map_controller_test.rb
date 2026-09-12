require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "the map page renders with the API url for the map controller" do
    get root_path
    assert_response :success
    assert_select "[data-controller=map][data-map-api-value]"
    assert_select ".card[hidden]"
  end

  test "styleguide renders" do
    get styleguide_path
    assert_response :success
    assert_select ".display", "LS33 9XX 17"
  end
end
