require "test_helper"

class ContributionPinsTest < ActionDispatch::IntegrationTest
  test "pins are this device's contributions with a point and a status" do
    post contributions_path, params: { contribution: { kind: "confirm_address", building_id: buildings(:two).ingest_id } }
    post contributions_path, params: { contribution: { kind: "confirm_district", target_code: "LS1" } }

    get pins_contributions_path, headers: { "Accept" => "application/json" }
    assert_response :success
    fc = response.parsed_body
    assert_equal "FeatureCollection", fc["type"]
    by_label = fc["features"].index_by { |f| f["properties"]["label"] }
    assert_equal %w[LS1 LS1\ 1CC\ 2], by_label.keys.sort, "only this device's two, not the fixtures' from other devices"

    building = by_label["LS1 1CC 2"]
    assert_equal [ buildings(:two).lng, buildings(:two).lat ], building["geometry"]["coordinates"]
    assert_equal "pending", building["properties"]["status"]
    assert_match %r{\A/contributions/}, building["properties"]["url"]

    district = by_label["LS1"]
    assert_equal [ places(:kabulonga).centroid_lng, places(:kabulonga).centroid_lat ], district["geometry"]["coordinates"], "a district pin sits on its centroid"
    assert_nil district["properties"]["name"]
    assert_equal "confirm_district", district["properties"]["kind"]
  end

  test "a contribution on an unknown place has no pin" do
    contributions(:other_disputes_district).update!(target_code: "LS99")
    assert_nil contributions(:other_disputes_district).coordinates({})
  end
end
