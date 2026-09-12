class PlacesController < ApplicationController
  # Contributing is anonymous; only the review surfaces (phase 2) sign in.
  allow_unauthenticated_access
  def show
    gazetteer = current_gazetteer or return redirect_to(root_path, alert: t("contributions.no_gazetteer"))
    @place = gazetteer.places.find_by!(code: params[:code])
    @children = gazetteer.places.where(parent_code: @place.code).order(:code)
    @contributions = Contribution.kept.where(gazetteer_version: gazetteer, target_code: @place.code).recent.limit(50)
  end
end
