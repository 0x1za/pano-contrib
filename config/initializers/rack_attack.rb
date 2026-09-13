# Contributions are anonymous, so the only brakes are per device and per
# address. Generous for a person, tight for a script.
class Rack::Attack
  # Street lookups hit an outside provider; keep one browser from flooding it.
  throttle("geocode/ip", limit: 120, period: 1.hour) { |req| req.ip if req.path == "/geocode" }

  throttle("contributions/device", limit: 60, period: 1.hour) do |req|
    req.cookies["pano_device"] if req.post? && req.path.start_with?("/contributions")
  end

  throttle("contributions/ip", limit: 300, period: 1.hour) do |req|
    req.ip if req.post? && req.path.start_with?("/contributions")
  end

  # The offline outbox replays in batches; a batch is one request.
  throttle("sync/device", limit: 60, period: 1.hour) { |req| req.cookies["pano_device"] if req.post? && req.path == "/sync/push" }

  self.throttled_responder = lambda do |_req|
    [ 429, { "content-type" => "text/plain" }, [ "Too many contributions for now. Try again in a while.\n" ] ]
  end
end
