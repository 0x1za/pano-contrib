# Nightly: the age-based rule (a delivery note unopposed for 30 days) has no
# vote to trigger it, so re-run the acceptance rules over what is pending.
class SettleContributionsJob < ApplicationJob
  queue_as :background

  def perform
    Contribution.kept.status_pending.where(kind: :delivery_note).find_each(&:reconsider!)
  end
end
