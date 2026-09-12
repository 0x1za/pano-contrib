# The moderator queue: pending contributions, moderator-only kinds first,
# oldest first. Accept or reject with a note; the rest is keyboard.
class ReviewsController < ApplicationController
  before_action :require_reviewer

  def index
    @contributions = Contribution.kept.queue.includes(:building, :gazetteer_version, :votes).limit(50)
    @counts = Contribution.kept.status_pending.group(:kind).count
  end

  def update
    contribution = Contribution.kept.status_pending.find(params[:id])
    note = params[:note].to_s.strip.presence
    case params[:decision]
    when "accept" then contribution.accept!(by: current_user, note: note)
    when "reject" then contribution.reject!(by: current_user, note: note)
    else return redirect_to review_path, alert: t(".unknown_decision")
    end
    redirect_to review_path, notice: t(".#{params[:decision]}ed", label: contribution.target_label)
  end
end
