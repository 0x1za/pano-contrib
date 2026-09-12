# Changesets for moderators: draft the next batch, freeze it as
# changes.json for zoning, and see the churn once a cut applied it.
class ChangesetsController < ApplicationController
  before_action :require_reviewer
  before_action :require_gazetteer, only: :create

  def index
    @changesets = Changeset.recent.includes(:gazetteer_version, :exported_by)
    @unassigned = Contribution.kept.status_accepted.where(changeset_id: nil).count
  end

  def show
    @changeset = Changeset.find(params[:id])
    @contributions = @changeset.contributions.kept.recent.includes(:building).limit(200)
  end

  # Draft (or refresh the draft) for the current gazetteer.
  def create
    changeset = Changeset.draft!(current_gazetteer)
    redirect_to changeset_path(changeset), notice: t(".drafted", count: changeset.summary["contributions"])
  end

  def export
    changeset = Changeset.find(params[:id])
    changeset.export!(by: current_user)
    redirect_to changeset_path(changeset), notice: t(".exported")
  rescue ArgumentError => e
    redirect_to changeset_path(changeset), alert: e.message
  end

  def download
    changeset = Changeset.find(params[:id])
    send_data changeset.to_json_file, filename: "changes-#{changeset.gazetteer_version.version}-#{changeset.id.first(8)}.json", type: "application/json"
  end

  private
    def require_gazetteer
      redirect_to changesets_path, alert: t("contributions.no_gazetteer") unless current_gazetteer
    end
end
