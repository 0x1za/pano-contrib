require "net/http"

# Streets, schools, markets and other places people already know, from
# OpenStreetMap through Photon, so someone can type "Chila Road" and land
# near their house before tapping its roof. Bounded to the town the map is
# looking at, cached for a day, proxied here so the provider sees one
# polite client.
class Geocoder
  class Error < StandardError; end

  Result = Data.define(:name, :detail, :kind, :lat, :lng)

  DEFAULT_URL = "https://photon.komoot.io/api/".freeze
  # Lusaka district with a margin: the same box scripts/fetch-data.sh uses.
  # The fallback when the pano API cannot say where a town is.
  BBOX = "28.05,-15.75,28.55,-15.20".freeze
  MARGIN = 0.1
  LIMIT = 6

  mattr_accessor :transport, default: ->(uri) { request(uri) }

  def self.base_url
    ENV.fetch("PANO_GEOCODER_URL", DEFAULT_URL)
  end

  def self.search(q, town: nil)
    q = q.to_s.strip
    return [] if q.length < 3
    bbox = bbox_for(town)
    Rails.cache.fetch([ "geocode", bbox, q.downcase ], expires_in: 1.day) do
      uri = URI(base_url)
      uri.query = URI.encode_www_form(q: q, limit: LIMIT, bbox: bbox, lang: "en")
      parse(transport.call(uri))
    end
  end

  # The box of the town with this area prefix, with a margin, from the
  # pano API's town list; Lusaka's when the town is unknown or the API is
  # away. Pure given the towns.
  def self.bbox_for(town)
    towns = begin
      status, body = PanoApi.meta
      status == 200 ? body.fetch("towns", []) : []
    rescue PanoApi::Error
      []
    end
    bbox_from(towns, town)
  end

  def self.bbox_from(towns, town)
    t = towns.find { |x| x["area"] == town.to_s.upcase } || towns.first
    return BBOX unless t && t["bbox"]
    b = t["bbox"]
    [ b["min_lng"] - MARGIN, b["min_lat"] - MARGIN, b["max_lng"] + MARGIN, b["max_lat"] + MARGIN ].map { |v| format("%.3f", v) }.join(",")
  end

  # Pure: Photon's GeoJSON in, results out. Streets come first, since a
  # street is what people know; the rest keep Photon's order.
  def self.parse(body)
    features = JSON.parse(body).fetch("features", [])
    results = features.filter_map do |f|
      p = f["properties"] || {}
      lng, lat = f.dig("geometry", "coordinates")
      next unless p["name"].present? && lat && lng
      kind = p["osm_key"] == "highway" ? "street" : "place"
      detail = [ p["street"], p["district"] || p["locality"] || p["suburb"], p["city"] ].compact.uniq.reject { |x| x == p["name"] }.first(2).join(", ")
      Result.new(name: p["name"], detail: detail, kind: kind, lat: lat, lng: lng)
    end
    results.sort_by.with_index { |r, i| [ r.kind == "street" ? 0 : 1, i ] }
  end

  def self.request(uri)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 5) do |http|
      http.get(uri.request_uri, { "User-Agent" => "pano-contrib (https://github.com/0x1za/pano-contrib)" })
    end
    raise Error, "geocoder returned #{res.code}" unless res.code == "200"
    res.body
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "geocoder unreachable: #{e.message}"
  end
end
