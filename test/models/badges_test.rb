require "test_helper"

class BadgesTest < ActiveSupport::TestCase
  CASES = [
    [ {}, [], "nothing accepted, nothing earned" ],
    [ { accepted: 1, homes_confirmed: 1 }, %i[pano], "an accepted I-live-here is pano" ],
    [ { accepted: 1 }, [], "one accepted name is not pano; pano is living somewhere" ],
    [ { accepted: 10 }, %i[street], "ten acceptances are a street" ],
    [ { accepted: 50 }, %i[street block], "fifty keep the street and add the block" ],
    [ { accepted: 200 }, %i[street block compound], "two hundred: a compound" ],
    [ { names_accepted: 1 }, %i[signwriter], "a name the map now uses" ],
    [ { reports_accepted: 1 }, %i[sharp_eyes], "a confirmed report" ],
    [ { blocks_accepted: 1 }, %i[caretaker], "a described shared building" ],
    [ { notes_accepted: 4 }, [], "four notes are not five" ],
    [ { notes_accepted: 5 }, %i[courier], "five accepted notes make a courier" ],
    [ { districts: 5 }, %i[explorer], "five districts" ],
    [ { weeks: 4 }, %i[regular], "four different weeks" ],
    [ { votes: 25 }, %i[second_opinion], "twenty-five votes" ],
    [ { votes: 100 }, %i[second_opinion referee], "a hundred votes keep the second opinion and add referee" ],
    [ { first_cut: 1 }, %i[founder], "contributed against v0.1.0" ]
  ].freeze

  test "next names the closest chased badge and the distance to it" do
    badge, distance = Badges.next({ accepted: 8, votes: 3, weeks: 1 })
    assert_equal :street, badge.key
    assert_equal 2, distance
    assert_nil Badges.next({ accepted: 200, votes: 100, notes_accepted: 5, districts: 5, weeks: 4 }), "every chased badge earned; the one-off marks are not chased"
    assert_nil Badges.next({ accepted: 200, votes: 100, notes_accepted: 5, districts: 5, weeks: 4, names_accepted: 0 })
  end

  test "a person's stats come from their contributions" do
    c = contributions(:phone_confirms_one)
    c.update!(user: users(:one))
    c.accept!(by: users(:moderator))
    stats = users(:one).stats
    assert_equal 1, stats[:accepted]
    assert_equal 1, stats[:homes_confirmed]
    assert_equal 1, stats[:districts], "LS1, from the building"
    assert_equal 1, stats[:weeks]
    assert_equal 1, stats[:first_cut], "the fixture gazetteer is v0.1.0"
    assert_equal %i[pano founder], users(:one).badges.map(&:key)
  end
end
