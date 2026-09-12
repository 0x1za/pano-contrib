require "test_helper"

# /avo and /flipper do not exist for anyone but an admin.
class AdminConstraintTest < ActionDispatch::IntegrationTest
  test "signed out and moderators get 404" do
    get "/avo"
    assert_response :not_found
    get "/flipper"
    assert_response :not_found
    sign_in_as(users(:moderator))
    get "/avo"
    assert_response :not_found
  end

  test "an admin reaches both dashboards" do
    sign_in_as(users(:admin))
    get "/flipper/features"
    assert_response :success
    get "/avo/resources/contributions"
    assert_response :success
  end
end
