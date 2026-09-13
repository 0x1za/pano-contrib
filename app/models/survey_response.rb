# One resident's answers, recorded by the field worker's account. A
# response with a building is the resident pointing at their own house
# and agreeing it sits in this district: the strongest evidence we get.
class SurveyResponse < ApplicationRecord
  belongs_to :survey
  belongs_to :recorded_by, class_name: "User"
  belongs_to :building, optional: true

  scope :recent_first, -> { order(created_at: :desc) }

  normalizes :calls_it, with: ->(n) { n.strip.squeeze(" ").presence }
  normalizes :address, with: ->(a) { a.strip.upcase.squeeze(" ").presence }

  validates :recognises, inclusion: { in: [ true, false ] }
  validates :calls_it, length: { maximum: 80 }, allow_nil: true
  validates :note, length: { maximum: 280 }, allow_nil: true
  validate :building_in_district

  before_validation :resolve_address

  private
    # `LS1 1JC 17` names a building in the survey's gazetteer; a bare
    # unit or nothing at all is fine too, the resident may not know it.
    def resolve_address
      return if address.blank? || building.present?
      unit, number = address.rpartition(" ").values_at(0, 2)
      return unless number =~ /\A\d+\z/
      self.building = survey.gazetteer_version.buildings.find_by(unit_code: unit, number: number.to_i)
      errors.add(:address, "is not a building in this gazetteer") if building.nil?
    end

    def building_in_district
      return if building.nil?
      errors.add(:address, "is in #{building.district_code}, not #{survey.target_code}") unless building.district_code == survey.target_code
    end
end
