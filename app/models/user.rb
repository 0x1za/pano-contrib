# An account. Contributing never needs one; signing up claims the device's
# history and lets a person vote from several devices as one voice.
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :devices, dependent: :nullify
  has_many :contributions, dependent: :nullify
  has_many :votes, dependent: :nullify
  has_many :reviews, class_name: "Contribution", foreign_key: :reviewed_by_id, dependent: :nullify, inverse_of: :reviewed_by
  has_many :surveys, foreign_key: :opened_by_id, dependent: :restrict_with_error, inverse_of: :opened_by
  has_many :survey_responses, foreign_key: :recorded_by_id, dependent: :restrict_with_error, inverse_of: :recorded_by

  # Contributors manage their own; moderators review; admins manage users
  # and changesets. Reputation is a counter, not a permission.
  enum :role, { contributor: 0, moderator: 1, admin: 2 }, prefix: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :display_name, with: ->(n) { n.strip.presence }

  validates :display_name, length: { maximum: 40 }, allow_nil: true

  def reviewer?
    role_moderator? || role_admin?
  end

  # Anonymous history follows the person: the device and every contribution
  # and vote it made become the account's. A device already claimed stays
  # with its first account; later contributions carry their own user.
  def claim!(device)
    return if device.nil? || device.user_id.present?
    transaction do
      device.update!(user: self)
      device.contributions.where(user_id: nil).update_all(user_id: id)
      device.votes.where(user_id: nil).update_all(user_id: id)
    end
  end

  def name
    display_name.presence || email_address.split("@").first
  end

  # What appears on the leaderboard: only a name the person chose.
  def public_name
    display_name.presence || I18n.t("leaderboard.anonymous")
  end

  def stats
    Badges.stats(contributions: contributions, votes: votes)
  end

  def badges
    Badges.earned(stats)
  end
end
