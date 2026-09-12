require "test_helper"

class GeocoderTest < ActiveSupport::TestCase
  PHOTON = <<~JSON
    {"features":[
      {"geometry":{"coordinates":[28.3506,-15.4233]},"properties":{"name":"Kabulonga Boys School","osm_key":"amenity","osm_value":"school","street":"Twinpalm Road","district":"Tukunka","city":"Lusaka"}},
      {"geometry":{"coordinates":[28.3395,-15.4219]},"properties":{"name":"Kabulonga Road","osm_key":"highway","osm_value":"secondary","district":"Sunningdale","city":"Lusaka"}},
      {"geometry":{"coordinates":[28.25,-15.42]},"properties":{"osm_key":"shop"}}
    ]}
  JSON

  setup do
    @cache, @transport = Rails.cache, Geocoder.transport
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache, Geocoder.transport = @cache, @transport }

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

  test "search asks the provider once per query within the Lusaka box and caches" do
    calls = []
    Geocoder.transport = ->(uri) { calls << uri; PHOTON }
    assert_equal 2, Geocoder.search("kabulonga").size
    assert_equal 2, Geocoder.search("Kabulonga ").size
    assert_equal 1, calls.size, "the second lookup is a cache hit"
    params = URI.decode_www_form(calls.first.query).to_h
    assert_equal "28.05,-15.75,28.55,-15.20", params["bbox"]
    assert_equal "kabulonga", params["q"]
  end

  test "short queries are not sent anywhere" do
    Geocoder.transport = ->(*) { flunk "should not be called" }
    assert_equal [], Geocoder.search("ka")
  end
end
