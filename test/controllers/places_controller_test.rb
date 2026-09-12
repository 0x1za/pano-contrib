require "test_helper"

class PlacesControllerTest < ActionDispatch::IntegrationTest
  test "a district page shows its name, count and recent contributions" do
    get place_path("LS1")
    assert_response :success
    assert_select "h1", "Kabulonga"
    assert_select ".list li", 1
    assert_select "a.btn", /Yes, this is Kabulonga/
  end

  test "an unknown code is 404" do
    get place_path("LS99")
    assert_response :not_found
  end
end
