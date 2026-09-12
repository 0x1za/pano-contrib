# A district, sector or unit as published in one gazetteer version. Places
# are imported and never edited; a contribution points at a code, not a
# row, so it survives a re-cut.
class Place < ApplicationRecord
  belongs_to :gazetteer_version

  enum :tier, { district: 0, sector: 1, unit: 2 }, prefix: true

  scope :in_district, ->(code) { where(parent_code: code).or(where(code: code)) }

  validates :code, :centroid_lat, :centroid_lng, presence: true
  validates :code, uniqueness: { scope: :gazetteer_version_id }

  def display_name
    name.presence || code
  end
end
