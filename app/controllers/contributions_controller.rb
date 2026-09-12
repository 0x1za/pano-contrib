class ContributionsController < ApplicationController
  # Contributing is anonymous; only the review surfaces (phase 2) sign in.
  allow_unauthenticated_access
  before_action :require_gazetteer

  def index
    @contributions = current_device_contributions.recent.limit(100)
  end

  def show
    @contribution = current_device_contributions.find(params[:id])
  end

  # This visitor's contributions as GeoJSON points for the map, each with
  # its status, so a person can see what they said and what became of it.
  def pins
    contributions = current_device_contributions.recent.includes(:building).limit(500)
    places = Place.where(gazetteer_version: current_gazetteer, code: contributions.filter_map(&:target_code)).index_by(&:code)
    features = contributions.filter_map do |c|
      lnglat = c.coordinates(places)
      next unless lnglat
      { type: "Feature", geometry: { type: "Point", coordinates: lnglat },
        properties: { id: c.id, status: c.status, kind: c.kind, label: c.target_label, name: c.name, url: contribution_path(c) } }
    end
    render json: { type: "FeatureCollection", features: features }
  end

  # One form per kind. The target comes from the map: a building's pano
  # ingest id (the id the pano API and buildings.csv use) for address
  # kinds, a place code for the rest.
  def new
    @contribution = build_contribution(kind: params[:kind], building_id: params[:building_id], target_code: params[:target_code])
    if (existing = @contribution.duplicate_of)
      return redirect_to contribution_path(existing), notice: t("contributions.create.already", label: existing.target_label)
    end
    @building = @contribution.building
    @place = @contribution.target_code && current_gazetteer.places.find_by(code: @contribution.target_code)
  end

  def create
    @contribution = build_contribution(**contribution_params.to_h.symbolize_keys)
    if (existing = @contribution.duplicate_of)
      redirect_to contribution_path(existing), notice: t(".already", label: existing.target_label)
    elsif @contribution.save
      redirect_to contribution_path(@contribution), notice: t(".saved")
    else
      @building = @contribution.building
      @place = @contribution.target_code && current_gazetteer.places.find_by(code: @contribution.target_code)
      render :new, status: :unprocessable_content
    end
  end

  private
    def require_gazetteer
      redirect_to root_path, alert: t("contributions.no_gazetteer") unless current_gazetteer
    end

    # This device's, plus the account's from other devices once signed in.
    def current_device_contributions
      scope = Contribution.kept
      return scope.where(user: current_user) if current_user
      Current.device ? scope.where(device: Current.device) : Contribution.none
    end

    def contribution_params
      params.expect(contribution: [ :kind, :building_id, :target_code, :lat, :lng, :mutation_id, payload: [ :reason, :name, :note, :sub, :homes, :labelling ] ])
    end

    def build_contribution(kind:, building_id: nil, target_code: nil, lat: nil, lng: nil, mutation_id: nil, payload: {})
      building = building_id.present? ? current_gazetteer.buildings.find_by!(ingest_id: building_id) : nil
      target_kind = if building then :building
      elsif lat.present? then :point
      else Place.find_by(gazetteer_version: current_gazetteer, code: target_code)&.tier || :district
      end
      Contribution.new(
        kind: kind, building: building, target_code: target_code, target_kind: target_kind,
        lat: lat, lng: lng, payload: payload.to_h.compact_blank, mutation_id: mutation_id.presence,
        gazetteer_version: current_gazetteer, device: current_device, user: Current.user
      )
    end
end
