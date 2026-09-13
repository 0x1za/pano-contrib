# /api/... forwards to the pano API, so the browser has one origin to talk to.
class ApiController < ApplicationController
  allow_unauthenticated_access

  def show
    path = "/#{params[:path]}"
    return head :not_found unless ApiProxy.allowed?(path)
    res = ApiProxy.fetch(path, request.query_string, request.headers)
    res.headers.each { |k, v| response.set_header(k, v) unless k == "Content-Length" }
    return head res.status if res.status == 304 || res.body.empty?
    send_data res.body, status: res.status, type: res.headers["Content-Type"] || "application/octet-stream", disposition: "inline"
  rescue ApiProxy::Error => e
    Rails.logger.warn("api proxy: #{e.message}")
    render json: { error: "api_unreachable", detail: "the pano API is not reachable from this server" }, status: :bad_gateway
  end
end
