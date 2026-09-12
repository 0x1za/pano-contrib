# One delivery point, `LS33 9XX 17`, as published in one gazetteer version.
class Building < ApplicationRecord
  belongs_to :gazetteer_version
  has_many :contributions, dependent: :restrict_with_error

  validates :ingest_id, :unit_code, :number, :lat, :lng, presence: true
  validates :number, numericality: { greater_than: 0 }

  def address
    "#{unit_code} #{number}"
  end

  def district_code
    unit_code.split(" ").first
  end
end
