require "net/http"

# The map in the browser talks to the pano API through the app's own
# origin: /api/... is forwarded to PANO_API_URL. One host to reach, no
# CORS, and a phone on the same Wi-Fi as a laptop running the API still
# sees the map. Only the API's read routes are forwarded; range requests
# and ETags pass through so tiles and caching behave as they would direct.
class ApiProxy
  class Error < StandardError; end

  Response = Data.define(:status, :headers, :body)

  ALLOWED = %r{\A/(meta|resolve/[^/]+|encode|buildings|units|search|districts|sectors|overlays/wards|tiles/pano\.pmtiles)\z}
  FORWARD_IN = %w[Range If-None-Match Accept Accept-Encoding].freeze
  FORWARD_OUT = %w[Content-Type Content-Encoding Vary ETag Content-Range Accept-Ranges Cache-Control Content-Length].freeze

  mattr_accessor :transport, default: ->(uri, headers) { request(uri, headers) }

  def self.allowed?(path)
    ALLOWED.match?(path)
  end

  # Fetches `path` (with `query`) from the API, forwarding the request
  # headers that matter and keeping the response headers that matter.
  def self.fetch(path, query, request_headers)
    raise Error, "not an API route" unless allowed?(path)
    # Rails hands the path decoded; each segment goes back out encoded.
    encoded = path.split("/", -1).map { |seg| ERB::Util.url_encode(seg) }.join("/")
    uri = URI.join(PanoApi.base_url, encoded)
    uri.query = query.presence
    headers = FORWARD_IN.filter_map { |h| (v = request_headers[h]).present? ? [ h, v ] : nil }.to_h
    transport.call(uri, headers)
  end

  def self.request(uri, headers)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 15) do |http|
      http.get(uri.request_uri, headers)
    end
    out = FORWARD_OUT.filter_map { |h| (v = res[h]).present? ? [ h, v ] : nil }.to_h
    # Gazetteer answers change only with the gazetteer, whose hash is the
    # ETag: let the browser keep them for a day and revalidate after.
    out["Cache-Control"] ||= "public, max-age=86400" if res["ETag"].present?
    Response.new(status: res.code.to_i, headers: out, body: res.body.to_s)
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "pano API unreachable at #{PanoApi.base_url}: #{e.message}"
  end
end
