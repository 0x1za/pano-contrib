require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "the about page explains the address and what a visitor can do" do
    get about_path
    assert_response :success
    assert_select "h1", "What pano is"
    assert_select ".example span", count: 3
    assert_equal "LS33 9XX 17", css_select(".example span").map(&:text).join(" ")
    assert_select "a[href='/']", "To the map"
  end

  test "the header links to about from every page" do
    get contributions_path
    assert_select "header nav a[href='/about']", "About"
  end
end
