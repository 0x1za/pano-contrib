require "test_helper"

class ChangesetTest < ActiveSupport::TestCase
  setup do
    @version = gazetteer_versions(:current)
    @mod = users(:moderator)
  end

  def accept(kind, **attrs)
    c = Contribution.create!(kind: kind, gazetteer_version: @version, device: Device.issue!.first, **attrs)
    c.accept!(by: @mod)
    c
  end

  test "a draft gathers accepted, unassigned contributions and builds the export" do
    accept(:name_place, target_kind: :unit, target_code: "LS1 1CC", payload: { "name" => "Sable Road side" })
    accept(:dispute_district, target_kind: :district, target_code: "LS1", payload: { "name" => "Ibex Hill" })
    accept(:confirm_address, target_kind: :building, building: buildings(:one), payload: { "sub" => "3" })
    accept(:confirm_address, target_kind: :building, building: buildings(:one), payload: { "sub" => "B" })
    accept(:confirm_address, target_kind: :building, building: buildings(:two))
    accept(:missing_building, target_kind: :point, lat: -15.41, lng: 28.34, payload: { "note" => "new house" })
    pending = contributions(:phone_confirms_one)

    draft = Changeset.draft!(@version)
    assert draft.status_draft?
    assert_equal 6, draft.summary["contributions"]
    assert_nil pending.reload.changeset, "pending contributions are not gathered"
    changes = draft.export
    assert_equal "0.1.0", changes["gazetteer"]
    assert_equal @version.sha256, changes["generated_by"]
    assert_equal({ "LS1 1CC" => "Sable Road side", "LS1" => "Ibex Hill" }, changes["names"])
    assert_equal({ "LS1 1CC 1" => %w[3 B] }, changes["sub_addresses"], "homes accumulate per delivery point; a plain confirmation adds none")
    assert_equal [ { "lat" => -15.41, "lng" => 28.34, "note" => "new house" } ], changes["buildings"]
    assert_equal [], changes["disputed_cells"]
  end

  test "drafting again refreshes the same draft and picks up new acceptances" do
    first = Changeset.draft!(@version)
    assert_equal 0, first.summary["contributions"]
    accept(:confirm_address, target_kind: :building, building: buildings(:two))
    again = Changeset.draft!(@version)
    assert_equal first, again
    assert_equal 1, again.summary["contributions"]
  end

  test "export freezes the file and applied stores the churn" do
    accept(:dispute_district, target_kind: :district, target_code: "LS1", payload: { "name" => "Ibex Hill" })
    changeset = Changeset.draft!(@version)
    changeset.export!(by: @mod)
    assert changeset.status_exported?
    assert_equal @mod, changeset.exported_by
    frozen = changeset.to_json_file
    assert_includes frozen, "\"Ibex Hill\""

    accept(:dispute_district, target_kind: :district, target_code: "LS1", payload: { "name" => "Later name" })
    assert_equal frozen, changeset.reload.to_json_file, "an exported changeset no longer changes"
    assert_raises(ArgumentError) { changeset.export!(by: @mod) }

    churn = { "total" => { "buildings" => 2, "same_address" => 1 }, "districts" => {} }
    changeset.applied!(version: "0.2.0", churn: churn)
    assert changeset.reload.status_applied?
    assert_equal "0.2.0", changeset.applied_in_version
    assert_equal 1, changeset.churn["total"]["same_address"]
  end

  test "the nightly job keeps a draft for the current gazetteer" do
    DraftChangesetJob.perform_now
    assert_equal 1, Changeset.status_draft.where(gazetteer_version: @version).count
  end
end
