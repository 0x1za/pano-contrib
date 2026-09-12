require "test_helper"

# The rules table from the plan, one row per case. Votes only ever accept.
class AcceptanceTest < ActiveSupport::TestCase
  def tally(agree: 0, disagree: 0, age: 0.days)
    Acceptance::Tally.new(agree: agree, disagree: disagree, age: age)
  end

  CASES = [
    [ "confirm_district", { agree: 4 }, :pending, "four agreements are not enough for a district" ],
    [ "confirm_district", { agree: 5 }, :accept, "five agreements confirm a district" ],
    [ "confirm_district", { agree: 5, disagree: 9 }, :accept, "votes never reject; disagreement waits for a moderator" ],
    [ "confirm_address", { agree: 2 }, :pending, "two agreements are not enough for an address" ],
    [ "confirm_address", { agree: 3 }, :accept, "three agreements confirm an address" ],
    [ "name_place", { agree: 5 }, :accept, "five unopposed agreements name a place" ],
    [ "name_place", { agree: 7, disagree: 1 }, :pending, "one disagreement blocks a name" ],
    [ "delivery_note", { agree: 1 }, :accept, "one agreement accepts a note" ],
    [ "delivery_note", { age: 30.days }, :accept, "thirty days unopposed accepts a note" ],
    [ "delivery_note", { age: 29.days }, :pending, "twenty-nine days is not thirty" ],
    [ "delivery_note", { age: 40.days, disagree: 1 }, :pending, "an opposed note waits however old" ],
    [ "dispute_address", { agree: 50 }, :pending, "disputes need a moderator" ],
    [ "dispute_district", { agree: 50 }, :pending, "district disputes need a moderator" ],
    [ "missing_building", { agree: 50 }, :pending, "missing buildings need a moderator" ],
    [ "boundary_move", { agree: 50 }, :pending, "boundary moves need a moderator" ]
  ].freeze

  CASES.each do |kind, votes, expected, reason|
    test "#{kind} with #{votes.inspect}: #{reason}" do
      assert_equal expected, Acceptance.decide(kind, tally(**votes)), reason
    end
  end

  test "moderator-only kinds are the four the plan names plus multi-occupancy" do
    assert_equal %w[dispute_district dispute_address missing_building boundary_move multi_occupancy], Acceptance::MODERATOR_ONLY
    assert Acceptance.moderator_only?("boundary_move")
    assert Acceptance.moderator_only?("multi_occupancy")
    assert_not Acceptance.moderator_only?("confirm_address")
  end
end
