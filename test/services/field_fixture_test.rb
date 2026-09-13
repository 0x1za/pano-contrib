require "test_helper"

class FieldFixtureTest < ActiveSupport::TestCase
  setup { @transport = PanoApi.transport }
  teardown { PanoApi.transport = @transport }

  Response = Struct.new(:code, :body, :headers) do
    def [](name) = headers[name]
  end

  test "residents who recognised the district and pointed at their house become hand-verified vectors" do
    survey = Survey.create!(gazetteer_version: gazetteer_versions(:current), opened_by: users(:moderator), target_code: "LS1", target_name: "Kabulonga", goal: 3)
    survey.responses.create!(recorded_by: users(:moderator), recognises: true, address: "LS1 1CC 1")
    survey.responses.create!(recorded_by: users(:moderator), recognises: true, address: "LS1 1CC 2")
    survey.responses.create!(recorded_by: users(:moderator), recognises: false, address: "LS1 1CC 1")
    survey.close!
    PanoApi.transport = ->(uri, _etag) {
      Response.new("200", { code: "LS1 1CC", tier: "unit", parents: { district: "LS1", sector: "LS1 1" }, cells: [ "5GPCH8MJ+" ] }.to_json, { "ETag" => '"x"' })
    }
    fixture = FieldFixture.new(survey).to_h
    assert_equal "hand-verified", fixture["status"]
    assert_equal "gazetteer/v0.1.0", fixture["gazetteer"]
    assert_equal gazetteer_versions(:current).sha256, fixture["generated_by"]
    assert_equal [ { "code" => "LS1 1CC", "cells" => [ "5GPCH8MJ+" ], "parent" => "LS1 1", "district" => "LS1" } ], fixture["vectors"], "one vector per unit, however many residents"
    assert_equal 3, fixture["survey"]["residents"]
  end
end
