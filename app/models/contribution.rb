# Something a person told us about an address or a place. Pending until a
# vote count or a moderator accepts it; never edited by the contributor
# after submission, only superseded by a later contribution.
class Contribution < ApplicationRecord
  include SoftDeletable

  KINDS_BY_TARGET = {
    building: %w[confirm_address dispute_address delivery_note],
    district: %w[confirm_district dispute_district],
    sector: %w[name_place],
    unit: %w[name_place],
    point: %w[missing_building]
  }.freeze

  DISPUTE_REASONS = %w[not_here not_a_building two_buildings wrong_number].freeze

  belongs_to :gazetteer_version
  belongs_to :device
  belongs_to :user, optional: true
  belongs_to :building, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  enum :kind, {
    confirm_address: 0, dispute_address: 1, confirm_district: 2, dispute_district: 3,
    name_place: 4, missing_building: 5, delivery_note: 6, boundary_move: 7
  }, prefix: true
  enum :status, { pending: 0, accepted: 1, rejected: 2, superseded: 3 }, prefix: true
  enum :target_kind, { district: 0, sector: 1, unit: 2, building: 3, point: 4 }, prefix: true

  scope :recent, -> { order(created_at: :desc) }

  before_validation { self.mutation_id ||= SecureRandom.uuid }

  validates :mutation_id, presence: true, uniqueness: { scope: :device_id }
  validates :building, presence: true, if: :target_kind_building?
  validates :target_code, presence: true, unless: -> { target_kind_building? || target_kind_point? }
  validates :lat, :lng, presence: true, if: :target_kind_point?
  validate :kind_matches_target
  validate :payload_matches_kind

  def target_label
    building ? building.address : target_code
  end

  def reason
    payload["reason"]
  end

  def name
    payload["name"]
  end

  private
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
      end
    end
end
