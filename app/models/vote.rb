# One person's agreement or disagreement with a pending contribution. A
# device votes once per contribution; a signed-in user's vote also counts
# once per account, so claiming a second device cannot double a vote.
class Vote < ApplicationRecord
  belongs_to :contribution
  belongs_to :device
  belongs_to :user, optional: true

  enum :stance, { agree: 1, disagree: -1 }, prefix: true

  validates :stance, presence: true
  validates :device_id, uniqueness: { scope: :contribution_id, message: "has already voted" }
  validates :user_id, uniqueness: { scope: :contribution_id, message: "has already voted" }, allow_nil: true
  validate :not_own_contribution

  private
    def not_own_contribution
      return unless contribution
      mine = contribution.device_id == device_id || (user_id.present? && contribution.user_id == user_id)
      errors.add(:base, "You cannot vote on your own contribution") if mine
    end
end
