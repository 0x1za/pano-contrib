# Something a person told us about an address or a place. Pending until a
# vote count or a moderator accepts it; never edited by the contributor
# after submission, only superseded by a later contribution.
class Contribution < ApplicationRecord
  include SoftDeletable

  KINDS_BY_TARGET = {
    building: %w[confirm_address dispute_address delivery_note multi_occupancy],
    district: %w[confirm_district dispute_district],
    sector: %w[name_place],
    unit: %w[name_place],
    point: %w[missing_building]
  }.freeze

  DISPUTE_REASONS = %w[not_here not_a_building two_buildings wrong_number].freeze

  # A home inside a shared building, as residents label it: `3`, `B`,
  # `BLOCK C 12`. Free text, normalised like the Rust core's SubAddress:
  # upper case, single spaces, 1 to 12 letters, digits and spaces.
  SUB_ADDRESS = /\A[A-Z0-9][A-Z0-9 ]{0,11}\z/
  MAX_HOMES = 500

  belongs_to :gazetteer_version
  belongs_to :device
  belongs_to :user, optional: true
  belongs_to :building, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :votes, dependent: :delete_all

  enum :kind, {
    confirm_address: 0, dispute_address: 1, confirm_district: 2, dispute_district: 3,
    name_place: 4, missing_building: 5, delivery_note: 6, boundary_move: 7, multi_occupancy: 8
  }, prefix: true
  enum :status, { pending: 0, accepted: 1, rejected: 2, superseded: 3 }, prefix: true
  enum :target_kind, { district: 0, sector: 1, unit: 2, building: 3, point: 4 }, prefix: true

  scope :recent, -> { order(created_at: :desc) }
  # The review queue: moderator-only kinds first, then by age, oldest first.
  scope :queue, -> {
    first = sanitize_sql_array([ "CASE WHEN kind IN (?) THEN 0 ELSE 1 END", kinds.values_at(*Acceptance::MODERATOR_ONLY) ])
    status_pending.order(Arel.sql(first), :created_at)
  }

  before_validation { self.mutation_id ||= SecureRandom.uuid }
  before_validation :normalise_sub_address

  validates :mutation_id, presence: true, uniqueness: { scope: :device_id }
  validates :building, presence: true, if: :target_kind_building?
  validates :target_code, presence: true, unless: -> { target_kind_building? || target_kind_point? }
  validates :lat, :lng, presence: true, if: :target_kind_point?
  validate :kind_matches_target
  validate :payload_matches_kind

  # `LS33 9XX 17`, or `LS33 9XX 17/3` when the contributor named their home.
  def target_label
    return target_code unless building
    sub_address.present? ? "#{building.address}/#{sub_address}" : building.address
  end

  def sub_address
    payload["sub"]
  end

  def homes
    payload["homes"]
  end

  # `[lng, lat]` for the map: the building, the place's centroid (looked up
  # in `places`, a code → Place hash), or the point itself.
  def coordinates(places = {})
    if building
      [ building.lng, building.lat ]
    elsif target_kind_point? && lat && lng
      [ lng, lat ]
    elsif (place = places[target_code])
      [ place.centroid_lng, place.centroid_lat ]
    end
  end

  def tally
    counts = votes.group(:stance).count
    Acceptance::Tally.new(agree: counts.fetch("agree", 0), disagree: counts.fetch("disagree", 0), age: Time.current - created_at)
  end

  def moderator_only?
    Acceptance.moderator_only?(kind)
  end

  # Re-runs the vote rules; called after every vote and by the nightly job
  # for the age-based rule. Votes can only accept.
  def reconsider!
    return unless status_pending?
    accept!(by: nil) if Acceptance.decide(kind, tally) == :accept
  end

  # Accepting by vote (`by: nil`) or by a named moderator. An earlier
  # accepted answer to the same question is superseded, and the
  # contributor's reputation goes up.
  def accept!(by:, note: nil)
    transaction do
      update!(status: :accepted, reviewed_by: by, reviewed_at: Time.current, review_note: note)
      supersede_earlier_answers!
      user&.increment!(:reputation)
    end
  end

  def reject!(by:, note: nil)
    transaction do
      update!(status: :rejected, reviewed_by: by, reviewed_at: Time.current, review_note: note)
      user&.decrement!(:reputation)
    end
  end

  # What a vote by this device or user would be, or nil if they may not.
  def votable_by?(device:, user:)
    return false unless status_pending?
    return false if device_id == device&.id || (user && user_id == user.id)
    votes.where(device: device).or(votes.where(user: user)).none?
  end

  def reason
    payload["reason"]
  end

  def name
    payload["name"]
  end

  private
    def normalise_sub_address
      return unless payload.is_a?(Hash) && payload.key?("sub")
      normalised = payload["sub"].to_s.split.join(" ").upcase
      payload["sub"] = normalised.presence
      payload.delete("sub") if normalised.empty?
    end

    # Naming kinds answer one question per target; the latest accepted
    # answer wins and the earlier ones become superseded. Confirmations
    # and notes stack, so they are left alone.
    def supersede_earlier_answers!
      return unless kind_name_place? || kind_dispute_district? || kind_dispute_address?
      Contribution.status_accepted.where(kind: kind, target_code: target_code, building_id: building_id)
        .where.not(id: id).update_all(status: Contribution.statuses[:superseded], version: Arel.sql("version + 1"), updated_at: Time.current)
    end

    def kind_matches_target
      return if target_kind.blank? || kind.blank?
      allowed = KINDS_BY_TARGET.fetch(target_kind.to_sym, [])
      errors.add(:kind, "cannot target a #{target_kind}") unless allowed.include?(kind)
    end

    def payload_matches_kind
      case kind
      when "dispute_address"
        errors.add(:payload, "needs a reason") unless DISPUTE_REASONS.include?(reason)
      when "dispute_district", "name_place"
        errors.add(:payload, "needs a name") if name.blank? || name.length > 80
      when "delivery_note"
        errors.add(:payload, "needs a note") if payload["note"].blank? || payload["note"].length > 280
      when "multi_occupancy"
        homes = payload["homes"].to_i
        errors.add(:payload, "needs how many homes, from 2 to #{MAX_HOMES}") unless homes.between?(2, MAX_HOMES)
        errors.add(:payload, "labelling note is too long") if payload["labelling"].to_s.length > 80
      end
      if sub_address.present? && !SUB_ADDRESS.match?(sub_address)
        errors.add(:payload, "home label can only be letters, digits and spaces, up to 12")
      end
    end
end
