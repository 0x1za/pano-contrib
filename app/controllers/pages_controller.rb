class PagesController < ApplicationController
  # Contributing is anonymous; only the review surfaces (phase 2) sign in.
  allow_unauthenticated_access
  def about
  end

  # Text-only contributions without a network; the service worker keeps
  # this page reachable and the outbox sends what is saved here later.
  def offline
    @api_url = PanoApi.base_url
  end

  def styleguide
  end
end
