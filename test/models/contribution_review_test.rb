require "test_helper"

class ContributionReviewTest < ActiveSupport::TestCase
  def votes_for(contribution, agree:, disagree: 0)
    (agree + disagree).times do |i|
      device = Device.issue!.first
      contribution.votes.create!(stance: i < agree ? :agree : :disagree, device: device)
    end
  end

  test "three agreements accept an address confirmation and credit the contributor" do
    c = contributions(:phone_confirms_one)
    c.update!(user: users(:one))
    votes_for(c, agree: 2)
    c.reconsider!
    assert c.reload.status_pending?, "two votes are not enough"
    votes_for(c, agree: 1)
    c.reconsider!
    assert c.reload.status_accepted?
    assert_nil c.reviewed_by, "accepted by votes, not by a person"
    assert_equal 1, users(:one).reload.reputation
  end

  test "a moderator's rejection records who and why and costs reputation" do
    c = contributions(:phone_confirms_one)
    c.update!(user: users(:one))
    c.reject!(by: users(:moderator), note: "This plot is empty.")
    assert c.reload.status_rejected?
    assert_equal users(:moderator), c.reviewed_by
    assert_equal "This plot is empty.", c.review_note
    assert_equal(-1, users(:one).reload.reputation)
  end

  test "accepting a later name supersedes the earlier accepted one" do
    earlier = Contribution.create!(kind: :name_place, target_kind: :unit, target_code: "LS1 1CC", payload: { "name" => "Sable" },
                                   gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    earlier.accept!(by: users(:moderator))
    accepted_version = earlier.reload.version
    later = Contribution.create!(kind: :name_place, target_kind: :unit, target_code: "LS1 1CC", payload: { "name" => "Sable Road side" },
                                 gazetteer_version: gazetteer_versions(:current), device: devices(:phone))
    later.accept!(by: users(:moderator))
    assert earlier.reload.status_superseded?
    assert_equal accepted_version + 1, earlier.version, "superseding bumps the version like any other change"
    assert later.reload.status_accepted?
  end

  test "confirmations stack instead of superseding each other" do
    first = contributions(:phone_confirms_one)
    first.accept!(by: users(:moderator))
    second = Contribution.create!(kind: :confirm_address, target_kind: :building, building: buildings(:one),
                                  gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    second.accept!(by: users(:moderator))
    assert first.reload.status_accepted?
  end

  test "the queue puts moderator-only kinds first, oldest first" do
    contributions(:phone_confirms_one).update!(created_at: 3.days.ago)
    contributions(:other_disputes_district).update!(created_at: 1.day.ago)
    assert_equal [ contributions(:other_disputes_district), contributions(:phone_confirms_one) ], Contribution.queue.to_a
  end

  test "votable_by refuses the author, a repeat voter and a settled contribution" do
    c = contributions(:other_disputes_district)
    assert c.votable_by?(device: devices(:phone), user: nil)
    assert_not c.votable_by?(device: devices(:other), user: nil), "the author's device"
    c.votes.create!(stance: :agree, device: devices(:phone))
    assert_not c.votable_by?(device: devices(:phone), user: nil), "already voted"
    c.accept!(by: users(:moderator))
    assert_not c.votable_by?(device: Device.issue!.first, user: nil), "settled"
  end

  test "the nightly job settles old unopposed delivery notes" do
    note = Contribution.create!(kind: :delivery_note, target_kind: :building, building: buildings(:one), payload: { "note" => "Green gate" },
                                gazetteer_version: gazetteer_versions(:current), device: devices(:phone), created_at: 31.days.ago)
    SettleContributionsJob.perform_now
    assert note.reload.status_accepted?
  end
end
