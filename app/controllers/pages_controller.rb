class PagesController < ApplicationController
  # Contributing is anonymous; only the review surfaces (phase 2) sign in.
  allow_unauthenticated_access
  def about
  end

  def styleguide
  end
end
