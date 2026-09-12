# Who has done the most for the map: all time by reputation, and this
# week by acceptances. Only accounts appear, and only by the name they
# chose; anonymous devices are counted in the totals but never listed.
class LeaderboardController < ApplicationController
  allow_unauthenticated_access

  def show
    @all_time = User.where("reputation > 0").order(reputation: :desc, created_at: :asc).limit(20)
    accepted_this_week = Contribution.kept.status_accepted.where(reviewed_at: 7.days.ago..).where.not(user_id: nil)
    counts = accepted_this_week.group(:user_id).count
    @this_week = User.where(id: counts.keys).sort_by { |u| -counts[u.id] }.first(20).map { |u| [ u, counts[u.id] ] }
    @totals = {
      contributions: Contribution.kept.count,
      accepted: Contribution.kept.status_accepted.count,
      contributors: Contribution.kept.distinct.count(:device_id),
      homes_described: Contribution.kept.status_accepted.where(kind: :multi_occupancy).distinct.count(:building_id)
    }
    @mine = current_user&.stats || Current.device&.stats
  end
end
