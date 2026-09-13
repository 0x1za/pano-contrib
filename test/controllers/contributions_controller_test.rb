require "test_helper"

class ContributionsControllerTest < ActionDispatch::IntegrationTest
  test "a first visit gets a device cookie and can confirm an address" do
    get new_contribution_path(kind: "confirm_address", building_id: buildings(:one).ingest_id)
    assert_response :success
    assert_select "h1", "LS1 1CC 1"
    assert_select "turbo-frame#modal h1", 1, "the form renders inside the modal frame so the map can open it in place"

    assert_difference -> { Contribution.count }, 1 do
      post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:one).ingest_id, mutation_id: SecureRandom.uuid } }
    end
    contribution = Contribution.recent.first
    assert_redirected_to contribution_path(contribution)
    assert_equal "confirm_address", contribution.kind
    assert_equal buildings(:one), contribution.building
    assert cookies[:pano_device].present?, "the device cookie is set on the first contribution"

    assert_no_difference -> { Device.count }, "the cookie resumes the same device" do
      post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    end
    mine = Contribution.where.not(device: [ devices(:phone), devices(:other) ])
    assert_equal [ contribution.device_id ], mine.distinct.pluck(:device_id)
  end

  test "a dispute without a reason re-renders the form" do
    post contributions_path, params: { contribution: { kind: "dispute_address", building_id: buildings(:one).ingest_id, payload: { reason: "" } } }
    assert_response :unprocessable_content
    assert_select ".flash.is-error", /needs a reason/
  end

  test "district renaming is retired: the form and the submit both bounce" do
    get new_contribution_path(kind: "dispute_district", target_code: "LS1")
    assert_redirected_to root_path
    assert_no_difference -> { Contribution.count } do
      post contributions_path, params: { contribution: { kind: "dispute_district", target_code: "LS1", payload: { name: "Ibex Hill" } } }
    end
    assert_redirected_to root_path
    assert_match(/Place names are set with the map/, flash[:alert])
  end

  test "a district can still be confirmed" do
    assert_difference -> { Contribution.count }, 1 do
      post contributions_path, params: { contribution: { kind: "confirm_district", target_code: "LS1" } }
    end
    assert_equal "district", Contribution.recent.first.target_kind
  end

  test "my contributions lists only this device's" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    get contributions_path
    assert_response :success
    assert_select ".entry", 1
    assert_select ".entry-label", "LS1 1CC 2"
    assert_select ".entry .pill.is-pending", "Pending"
  end

  test "another device cannot open my contribution" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    mine = Contribution.recent.first
    cookies.delete("pano_device")
    get contribution_path(mine)
    assert_response :not_found
  end

  test "without a gazetteer the forms redirect home" do
    Contribution.delete_all
    Building.delete_all
    Place.delete_all
    GazetteerVersion.delete_all
    get new_contribution_path(kind: "confirm_address")
    assert_redirected_to root_path
  end

  test "saying the same thing about the same place twice keeps the first" do
    post contributions_path, params: { contribution: { kind: "confirm_district", target_code: "LS1" } }
    first = Contribution.recent.first
    assert_no_difference -> { Contribution.count } do
      post contributions_path, params: { contribution: { kind: "confirm_district", target_code: "LS1" } }
    end
    assert_redirected_to contribution_path(first)
    assert_equal "You have already said this about LS1. Here it is.", flash[:notice]

    get new_contribution_path(kind: "confirm_district", target_code: "LS1")
    assert_redirected_to contribution_path(first), "the form itself sends a repeat to what was said"

    assert_difference -> { Contribution.count }, 1, "a different kind about the same place is a different question" do
      post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    end
    first.reject!(by: users(:moderator))
    assert_difference -> { Contribution.count }, 1 do
      post contributions_path, params: { contribution: { kind: "confirm_district", target_code: "LS1" } }
    end
  end

  test "the form warns that a second I-live-here moves the home, and sending it does" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:one).ingest_id } }
    first = Contribution.recent.first
    get new_contribution_path(kind: "confirm_address", building_id: buildings(:two).ingest_id)
    assert_response :success
    assert_select ".flash.is-warning", /You said you live at LS1 1CC 1/
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    assert first.reload.status_superseded?
    assert_equal 1, Contribution.kept.open.kind_confirm_address.where(device: first.device).count
  end

  test "a delivery note with a photo is stored stripped and shown on its page" do
    post contributions_path, params: { contribution: { kind: "delivery_note", building_id: buildings(:one).ingest_id, payload: { note: "Green gate" },
                                                        photo: fixture_file_upload("gate.jpg", "image/jpeg") } }
    c = Contribution.recent.first
    assert c.photo.attached?
    assert_redirected_to contribution_path(c)
    follow_redirect!
    assert_select "figure.photo img", 1
    assert_select "figure.photo figcaption", /Only you and the moderators/
  end

  test "a building contribution's blank target code is stored as nothing, so the queue can render it" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id, target_code: "" } }
    assert_nil Contribution.recent.first.target_code
    sign_in_as(users(:moderator))
    get review_path
    assert_response :success
  end
end
