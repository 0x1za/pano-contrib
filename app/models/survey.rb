# The field protocol: ten residents of one district, asked the same two
# things in person. "What do you call this area?" and "Is this <name>?"
# Answers are evidence for the maintainers, not votes, and the residents
# who also pointed at their building become hand-verified conformance
# fixtures for the Rust side.
class Survey < ApplicationRecord
  belongs_to :gazetteer_version
  belongs_to :opened_by, class_name: "User"
  has_many :responses, class_name: "SurveyResponse", dependent: :destroy

  enum :status, { open: 0, closed: 1 }, prefix: true

  validates :target_code, presence: true, format: { with: /\A[A-Z]{1,2}[1-9][0-9]?\z/, message: "must be a district code like LS33" }
  validates :goal, numericality: { in: 3..100 }

  scope :recent, -> { order(created_at: :desc) }

  def display_name
    target_name.presence || target_code
  end

  def done?
    responses.count >= goal
  end

  def progress
    [ responses.count, goal ]
  end

  # Share of residents who recognise the district by the name the map uses.
  def recognition
    n = responses.count
    return nil if n.zero?
    responses.where(recognises: true).count.fdiv(n)
  end

  # What residents call the area, most common first. "kabulonga" and
  # "Kabulonga" are one name, shown in its most common spelling.
  def names_heard
    responses.where.not(calls_it: [ nil, "" ]).pluck(:calls_it)
      .group_by(&:downcase)
      .map { |_, spellings| [ spellings.tally.max_by { |_, n| n }.first, spellings.size ] }
      .sort_by { |name, count| [ -count, name.downcase ] }
  end

  def close!
    update!(status: :closed, closed_at: Time.current)
  end

  # The report the maintainers read before touching seeds.toml.
  def report
    {
      "district" => target_code, "name" => display_name, "gazetteer" => gazetteer_version.version,
      "residents" => responses.count, "goal" => goal, "recognition" => recognition&.round(3),
      "names_heard" => names_heard.map { |name, count| { "name" => name, "count" => count } },
      "buildings_confirmed" => responses.where(recognises: true).where.not(building_id: nil).count
    }
  end
end
