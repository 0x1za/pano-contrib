class MapController < ApplicationController
  # Contributing is anonymous; only the review surfaces (phase 2) sign in.
  allow_unauthenticated_access
  def show
    @gazetteer = current_gazetteer
    @api_url = PanoApi.base_url
  end
end
