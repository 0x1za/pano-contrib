require "net/http"

# The pano API is the source of truth for what a code means. This client
# is small on purpose: GET, JSON, cached by the gazetteer ETag. Every pano
# response carries the gazetteer hash as its ETag, so a cached answer is
# revalidated with one conditional request and only refetched when a new
# gazetteer is published.
class PanoApi
  class Error < StandardError; end

  Cached = Struct.new(:etag, :status, :body)

  # (uri, etag) -> Net::HTTPResponse. Swappable so tests need no network.
  mattr_accessor :transport, default: ->(uri, etag) { request(uri, etag) }

  def self.base_url
    ENV.fetch("PANO_API_URL", "http://127.0.0.1:8080")
  end

  def self.encode(lat:, lng:)
    get("/encode", lat: lat, lng: lng)
  end

  def self.resolve(code)
    get("/resolve/#{ERB::Util.url_encode(code)}")
  end

  def self.search(q)
    get("/search", q: q)
  end

  def self.meta
    get("/meta")
  end

  # Returns [status, body]; 404s are answers here, not errors.
  def self.get(path, **params)
    uri = URI.join(base_url, path)
    uri.query = URI.encode_www_form(params) if params.any?
    key = [ "pano_api", uri.to_s ]

    cached = Rails.cache.read(key)
    res = transport.call(uri, cached&.etag)
    return [ cached.status, cached.body ] if res.code == "304" && cached

    raise Error, "#{uri} returned #{res.code}" unless %w[200 404].include?(res.code)
    entry = Cached.new(res["ETag"], res.code.to_i, JSON.parse(res.body))
    Rails.cache.write(key, entry, expires_in: 1.day) if entry.etag
    [ entry.status, entry.body ]
  end

  def self.request(uri, etag)
    headers = etag ? { "If-None-Match" => etag } : {}
    Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 5) { |http| http.get(uri.request_uri, headers) }
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "pano API unreachable at #{base_url}: #{e.message}"
  end
end
