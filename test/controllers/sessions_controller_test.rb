require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "new" do
    get new_session_path
    assert_response :success
    assert_select "h1", "Sign in"
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "signing in claims the device the person was contributing from" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    mine = Contribution.recent.first
    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_equal @user, mine.reload.user
    get contributions_path
    assert_select ".entry", 1
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
