require "test_helper"

class GeocoderTest < ActiveSupport::TestCase
  PHOTON = <<~JSON
    {"features":[
      {"geometry":{"coordinates":[28.3506,-15.4233]},"properties":{"name":"Kabulonga Boys School","osm_key":"amenity","osm_value":"school","street":"Twinpalm Road","district":"Tukunka","city":"Lusaka"}},
      {"geometry":{"coordinates":[28.3395,-15.4219]},"properties":{"name":"Kabulonga Road","osm_key":"highway","osm_value":"secondary","district":"Sunningdale","city":"Lusaka"}},
      {"geometry":{"coordinates":[28.25,-15.42]},"properties":{"osm_key":"shop"}}
    ]}
  JSON

  Response = Struct.new(:code, :body, :headers) do
    def [](name) = headers[name]
  end

  TOWNS = { towns: [
    { area: "LS", name: "Lusaka", lat: -15.42, lng: 28.32, bbox: { min_lng: 28.15, min_lat: -15.55, max_lng: 28.45, max_lat: -15.30 } },
    { area: "CL", name: "Chililabombwe", lat: -12.36, lng: 27.83, bbox: { min_lng: 27.62, min_lat: -12.45, max_lng: 27.99, max_lat: -12.24 } }
  ] }.to_json

  setup do
    @cache, @transport, @api = Rails.cache, Geocoder.transport, PanoApi.transport
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    PanoApi.transport = ->(_uri, _etag) { Response.new("200", TOWNS, { "ETag" => '"t"' }) }
  end

  teardown { Rails.cache, Geocoder.transport, PanoApi.transport = @cache, @transport, @api }

  test "parses Photon, drops nameless features, and puts streets first" do
    results = Geocoder.parse(PHOTON)
    assert_equal [ "Kabulonga Road", "Kabulonga Boys School" ], results.map(&:name)
    street = results.first
    assert_equal "street", street.kind
    assert_equal "Sunningdale, Lusaka", street.detail
    assert_in_delta(-15.4219, street.lat, 1e-6)
    assert_equal "place", results.last.kind
    assert_equal "Twinpalm Road, Tukunka", results.last.detail
  end

  test "search asks the provider once per query within the town's box and caches" do
    calls = []
    Geocoder.transport = ->(uri) { calls << uri; PHOTON }
    assert_equal 2, Geocoder.search("kabulonga", town: "LS").size
    assert_equal 2, Geocoder.search("Kabulonga ", town: "ls").size
    assert_equal 1, calls.size, "the second lookup is a cache hit"
    params = URI.decode_www_form(calls.first.query).to_h
    assert_equal "28.050,-15.650,28.550,-15.200", params["bbox"], "the town's unit box with a 0.1 degree margin"
    assert_equal "kabulonga", params["q"]
  end

  test "the box follows the town, and falls back to Lusaka when the API cannot say" do
    towns = JSON.parse(TOWNS)["towns"]
    assert_equal "27.520,-12.550,28.090,-12.140", Geocoder.bbox_from(towns, "CL")
    assert_equal "28.050,-15.650,28.550,-15.200", Geocoder.bbox_from(towns, "ZZ"), "an unknown town gets the first one"
    assert_equal Geocoder::BBOX, Geocoder.bbox_from([], "LS"), "no towns at all gets the constant"
    PanoApi.transport = ->(_uri, _etag) { raise PanoApi::Error, "away" }
    assert_equal Geocoder::BBOX, Geocoder.bbox_for("CL")
  end

  test "short queries are not sent anywhere" do
    Geocoder.transport = ->(*) { flunk "should not be called" }
    assert_equal [], Geocoder.search("ka")
  end
end
