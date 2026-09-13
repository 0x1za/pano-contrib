require "test_helper"

class SurveyTest < ActiveSupport::TestCase
  setup do
    @survey = Survey.create!(gazetteer_version: gazetteer_versions(:current), opened_by: users(:moderator), target_code: "LS1", target_name: "Kabulonga", goal: 3)
  end

  def record(recognises:, address: nil, calls_it: nil)
    @survey.responses.create!(recorded_by: users(:moderator), recognises: recognises, address: address, calls_it: calls_it)
  end

  test "the report tallies recognition and the names residents use" do
    record(recognises: true, address: "LS1 1CC 1", calls_it: "Kabulonga")
    record(recognises: true, calls_it: " kabulonga ")
    record(recognises: false, calls_it: "Ibex Hill")
    report = @survey.report
    assert_equal 3, report["residents"]
    assert_in_delta 0.667, report["recognition"], 0.001
    assert_equal [ { "name" => "Kabulonga", "count" => 2 }, { "name" => "Ibex Hill", "count" => 1 } ], report["names_heard"], "spellings fold together, most common spelling shown"
    assert_equal 1, report["buildings_confirmed"]
    assert @survey.done?
  end

  test "an address resolves to a building in the survey's district or is refused" do
    r = record(recognises: true, address: "ls1 1cc 2")
    assert_equal buildings(:two), r.building
    outside = @survey.responses.new(recorded_by: users(:moderator), recognises: true, address: "LS9 9ZZ 1")
    assert_not outside.valid?
    assert_includes outside.errors[:address], "is not a building in this gazetteer"
  end

  test "a survey needs a district code and a sane goal" do
    s = Survey.new(gazetteer_version: gazetteer_versions(:current), opened_by: users(:moderator), target_code: "LS1 1CC", goal: 2)
    assert_not s.valid?
    assert_includes s.errors[:target_code], "must be a district code like LS33"
    assert s.errors[:goal].any?
  end
end
