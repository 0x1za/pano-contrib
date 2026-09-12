# Street and place lookups for the map's search, proxied and cached.
class GeocodeController < ApplicationController
  allow_unauthenticated_access

  def index
    results = Geocoder.search(params[:q])
    render json: results.map(&:to_h)
  rescue Geocoder::Error => e
    Rails.logger.warn("geocode: #{e.message}")
    render json: [], status: :bad_gateway
  end
end
