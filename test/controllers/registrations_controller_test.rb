require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signups are closed until the flag opens them" do
    get new_registration_path
    assert_redirected_to new_session_path
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password", password_confirmation: "password" } }
    end
  end

  test "signing up claims the device and its contributions" do
    Flipper.enable(:signups)
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    mine = Contribution.recent.first
    assert_nil mine.user

    get new_registration_path
    assert_response :success
    assert_difference -> { User.count }, 1 do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password", password_confirmation: "password", display_name: " Bana Mwila " } }
    end
    assert_redirected_to contributions_path
    user = User.find_by!(email_address: "new@example.com")
    assert_equal "Bana Mwila", user.display_name
    assert_equal user, mine.reload.user, "the anonymous contribution now belongs to the account"
    assert_equal user, mine.device.user
  ensure
    Flipper.disable(:signups)
  end

  test "a bad password confirmation re-renders" do
    Flipper.enable(:signups)
    post registration_path, params: { user: { email_address: "new@example.com", password: "password", password_confirmation: "other" } }
    assert_response :unprocessable_content
    assert_select ".flash.is-error", /Password confirmation/
  ensure
    Flipper.disable(:signups)
  end
end
