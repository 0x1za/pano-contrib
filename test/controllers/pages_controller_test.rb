require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the about page explains the address and what a visitor can do" do
    get about_path
    assert_response :success
    assert_select "h1", "What pano is"
    assert_select ".example span", count: 3
    assert_equal "LS33 9XX 17", css_select(".example span").map(&:text).join(" ")
    assert_select "a[href='/']", "To the map"
    assert_select "turbo-frame#modal h1", 1, "renders inside the map's dialog when opened from there, as a page otherwise"
  end

  test "the header links to about from every page" do
    get contributions_path
    assert_select "header nav a[href='/about']", "About"
  end

  test "the offline form is a page the service worker can cache" do
    get offline_path
    assert_response :success
    assert_select "main[data-controller=offline][data-offline-api-value]"
    assert_select "[data-offline-target=saveMap]", false, "the saved map waits behind the :offline_map flag"
    Flipper.enable(:offline_map)
    get offline_path
    assert_select "[data-offline-target=saveMap]", text: /Save the map/
  ensure
    Flipper.disable(:offline_map)
    assert_select "input[data-offline-target=address][placeholder='LS33 9XX 17']"
    assert_select "select[data-offline-target=kind] option", 3
    assert_select "ul[data-offline-target=list]"
  end
end
