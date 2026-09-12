require "test_helper"

class BadgesTest < ActiveSupport::TestCase
  CASES = [
    [ {}, [], "nothing accepted, nothing earned" ],
    [ { accepted: 1 }, %i[first_step], "one acceptance is the first step" ],
    [ { accepted: 10 }, %i[first_step neighbour], "ten acceptances keep the first step and add neighbour" ],
    [ { accepted: 50, votes: 25 }, %i[first_step neighbour streetwise voter], "fifty and twenty-five votes" ],
    [ { accepted: 1, names_accepted: 1 }, %i[first_step cartographer], "an accepted name" ],
    [ { accepted: 1, disputes_accepted: 1 }, %i[first_step watchman], "an accepted report" ],
    [ { accepted: 1, homes_accepted: 1 }, %i[first_step landlord], "an accepted shared building" ],
    [ { votes: 24 }, [], "twenty-four votes is not twenty-five" ]
  ].freeze

  CASES.each do |stats, expected, reason|
    test "#{stats.inspect}: #{reason}" do
      assert_equal expected, Badges.earned(stats).map(&:key), reason
    end
  end

  test "next names the closest badge and the distance to it" do
    badge, distance = Badges.next({ accepted: 8, votes: 3 })
    assert_equal :neighbour, badge.key
    assert_equal 2, distance
    assert_nil Badges.next({ accepted: 50, votes: 25 }), "every counting badge earned; one-off badges are not chased"
  end

  test "a user's stats feed the badges" do
    c = contributions(:phone_confirms_one)
    c.update!(user: users(:one))
    c.accept!(by: users(:moderator))
    assert_equal %i[first_step], users(:one).badges.map(&:key)
    assert_equal 1, users(:one).stats[:accepted]
  end
end
