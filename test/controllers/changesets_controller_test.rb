require "test_helper"

class ChangesetsControllerTest < ActionDispatch::IntegrationTest
  test "changesets are for reviewers" do
    get changesets_path
    assert_redirected_to new_session_path
    sign_in_as(users(:one))
    get changesets_path
    assert_response :not_found
  end

  test "a moderator drafts, exports and downloads a changeset" do
    home = Contribution.create!(kind: :confirm_address, target_kind: :building, building: buildings(:one), payload: { "sub" => "3" },
                                gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    home.accept!(by: users(:moderator))
    sign_in_as(users(:moderator))
    get changesets_path
    assert_response :success
    assert_select "p.sub", /1 accepted contribution is waiting/

    assert_difference -> { Changeset.count }, 1 do
      post changesets_path
    end
    changeset = Changeset.last
    assert_redirected_to changeset_path(changeset)
    follow_redirect!
    assert_select "h1", changeset.id.first(8)
    assert_select ".list li strong", "LS1 1CC 1/3"

    patch export_changeset_path(changeset)
    assert changeset.reload.status_exported?
    get download_changeset_path(changeset)
    assert_response :success
    body = response.parsed_body
    assert_equal({ "LS1 1CC 1" => [ "3" ] }, body["sub_addresses"])
    assert_equal({}, body["names"])
    assert_equal gazetteer_versions(:current).sha256, body["generated_by"]
  end
end
