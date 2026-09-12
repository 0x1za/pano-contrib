require "test_helper"

class GeocodeControllerTest < ActionDispatch::IntegrationTest
  setup { @transport = Geocoder.transport }
  teardown { Geocoder.transport = @transport }

  test "answers with places as JSON" do
    Geocoder.transport = ->(*) { GeocoderTest::PHOTON }
    get geocode_path(q: "kabulonga road"), headers: { "Accept" => "application/json" }
    assert_response :success
    first = response.parsed_body.first
    assert_equal "Kabulonga Road", first["name"]
    assert_equal "street", first["kind"]
  end

  test "a provider failure is an empty answer, not a crash" do
    Geocoder.transport = ->(*) { raise Geocoder::Error, "down" }
    get geocode_path(q: "chila road"), headers: { "Accept" => "application/json" }
    assert_response :bad_gateway
    assert_equal [], response.parsed_body
  end
end
