require "net/http"

# Streets, schools, markets and other places people already know, from
# OpenStreetMap through Photon, so someone can type "Chila Road" and land
# near their house before tapping its roof. Bounded to Lusaka, cached for
# a day, proxied here so the provider sees one polite client.
class Geocoder
  class Error < StandardError; end

  Result = Data.define(:name, :detail, :kind, :lat, :lng)

  DEFAULT_URL = "https://photon.komoot.io/api/".freeze
  # Lusaka district with a margin: the same box scripts/fetch-data.sh uses.
  BBOX = "28.05,-15.75,28.55,-15.20".freeze
  LIMIT = 6

  mattr_accessor :transport, default: ->(uri) { request(uri) }

  def self.base_url
    ENV.fetch("PANO_GEOCODER_URL", DEFAULT_URL)
  end

  def self.search(q)
    q = q.to_s.strip
    return [] if q.length < 3
    Rails.cache.fetch([ "geocode", q.downcase ], expires_in: 1.day) do
      uri = URI(base_url)
      uri.query = URI.encode_www_form(q: q, limit: LIMIT, bbox: BBOX, lang: "en")
      parse(transport.call(uri))
    end
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
