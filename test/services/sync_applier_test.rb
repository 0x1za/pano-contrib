require "test_helper"

class SyncApplierTest < ActiveSupport::TestCase
  setup do
    @device = Device.issue!.first
    @gazetteer = gazetteer_versions(:current)
  end

  def apply(*mutations, device: @device, user: nil)
    SyncApplier.new(device: device, user: user, gazetteer: @gazetteer, mutations: mutations).call
  end

  def mutation(id, **args)
    { mutationId: id, type: "contribute", args: { kind: "confirm_address", address: "LS1 1CC 2" }.merge(args) }
  end

  test "an offline contribution is stored against the address it names, once" do
    first = apply(mutation("m1", kind: "delivery_note", note: "Green gate"))
    assert_equal [ "accepted" ], first.map(&:status), first.inspect
    c = Contribution.find(first.first.contribution_id)
    assert_equal buildings(:two), c.building
    assert_equal "Green gate", c.payload["note"]
    assert_equal "m1", c.mutation_id

    again = apply(mutation("m1", kind: "delivery_note", note: "Green gate"))
    assert_equal "duplicate", again.first.status
    assert_equal c.id, again.first.contribution_id
    assert_equal 1, Contribution.where(device: @device).count
  end

  test "an address with a home label lands on its building and keeps the label" do
    result = apply(mutation("m2", kind: "confirm_address", address: "ls1 1cc 2/flat 3")).first
    assert_equal "accepted", result.status, result.inspect
    assert_equal "LS1 1CC 2", Contribution.find(result.contribution_id).building.address
  end

  test "an unknown address, an unknown kind and a missing id are rejected with reasons" do
    results = apply(
      mutation("m3", address: "LS9 9ZZ 400"),
      mutation("m4", kind: "boundary_move"),
      { type: "contribute", args: {} },
      { mutationId: "m5", type: "delete" }
    )
    assert_equal %w[rejected rejected rejected rejected], results.map(&:status)
    assert_match(/not an address in this gazetteer/, results[0].reason)
    assert_match(/must be one of/, results[1].reason)
    assert_match(/mutation id missing/, results[2].reason)
    assert_match(/unknown mutation type/, results[3].reason)
    assert_equal 0, Contribution.where(device: @device).count
  end

  test "the one-open-per-place rule holds for a replayed batch too" do
    apply(mutation("m6")).first
    second = apply(mutation("m7")).first
    assert_equal "duplicate", second.status
    assert_match(/already said about LS1 1CC 2/, second.reason)
  end
end
