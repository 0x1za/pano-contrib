require "test_helper"

class ContributionTest < ActiveSupport::TestCase
  test "a confirmation needs a building and nothing else" do
    c = Contribution.new(kind: :confirm_address, target_kind: :building, building: buildings(:one),
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone))
    assert c.valid?, c.errors.full_messages.to_sentence
    assert c.mutation_id.present?, "a mutation id is minted when the client sends none"
  end

  test "a dispute needs a known reason" do
    c = Contribution.new(kind: :dispute_address, target_kind: :building, building: buildings(:one),
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone), payload: { "reason" => "vibes" })
    assert_not c.valid?
    assert_includes c.errors[:payload], "needs a reason"
    c.payload = { "reason" => "wrong_number" }
    assert c.valid?, c.errors.full_messages.to_sentence
  end

  test "kind must fit the target" do
    c = Contribution.new(kind: :confirm_address, target_kind: :district, target_code: "LS1",
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone))
    assert_not c.valid?
    assert_includes c.errors[:kind], "cannot target a district"
  end

  test "a name has to be short and present" do
    c = Contribution.new(kind: :name_place, target_kind: :unit, target_code: "LS1 1CC",
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone), payload: { "name" => "x" * 81 })
    assert_not c.valid?
    c.payload = { "name" => "Sable Road side" }
    assert c.valid?, c.errors.full_messages.to_sentence
  end

  test "a confirmation may name the home inside a shared building, normalised" do
    c = Contribution.new(kind: :confirm_address, target_kind: :building, building: buildings(:one),
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone), payload: { "sub" => " flat  3b " })
    assert c.valid?, c.errors.full_messages.to_sentence
    assert_equal "FLAT 3B", c.sub_address
    assert_equal "LS1 1CC 1/FLAT 3B", c.target_label
    c.payload = { "sub" => "3-B" }
    assert_not c.valid?
    assert_includes c.errors[:payload], "home label can only be letters, digits and spaces, up to 12"
    c.payload = { "sub" => "   " }
    assert c.valid?, "blank means one home"
    assert_nil c.sub_address
  end

  test "reporting several homes needs a count between 2 and 500" do
    c = Contribution.new(kind: :multi_occupancy, target_kind: :building, building: buildings(:one),
                         gazetteer_version: gazetteer_versions(:current), device: devices(:phone), payload: { "homes" => "1" })
    assert_not c.valid?
    assert_includes c.errors[:payload], "needs how many homes, from 2 to 500"
    c.payload = { "homes" => "20", "labelling" => "Numbers 1 to 20" }
    assert c.valid?, c.errors.full_messages.to_sentence
    assert c.moderator_only?
  end

  test "the same mutation from the same device is not stored twice" do
    existing = contributions(:phone_confirms_one)
    dup = Contribution.new(kind: :confirm_address, target_kind: :building, building: buildings(:one),
                           gazetteer_version: gazetteer_versions(:current), device: devices(:phone), mutation_id: existing.mutation_id)
    assert_not dup.valid?
    assert_includes dup.errors[:mutation_id], "has already been taken"
  end

  test "soft delete keeps the row and bumps the version" do
    c = contributions(:phone_confirms_one)
    assert_equal 1, c.version
    c.soft_delete!
    assert c.deleted?
    assert_equal 2, c.reload.version
    assert_not_includes Contribution.kept, c
  end
end
