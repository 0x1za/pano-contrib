# What a contributor has earned, from counts alone, so the whole table can
# be tested without a database. Badges never expire and never subtract:
# they mark what someone did, not how they rank.
#
# The ladder uses the map's own scale (a yard, a street, a block, a
# compound); the marks name the behaviours the scheme needs from people.
module Badges
  Badge = Data.define(:key, :threshold, :stat)

  ALL = [
    # The ladder: how much of the map you have fixed.
    Badge.new(key: :pano, threshold: 1, stat: :homes_confirmed),
    Badge.new(key: :street, threshold: 10, stat: :accepted),
    Badge.new(key: :block, threshold: 50, stat: :accepted),
    Badge.new(key: :compound, threshold: 200, stat: :accepted),
    # The marks: one for each thing the map needs people for.
    Badge.new(key: :sharp_eyes, threshold: 1, stat: :reports_accepted),
    Badge.new(key: :caretaker, threshold: 1, stat: :blocks_accepted),
    Badge.new(key: :courier, threshold: 5, stat: :notes_accepted),
    Badge.new(key: :explorer, threshold: 5, stat: :districts),
    Badge.new(key: :regular, threshold: 4, stat: :weeks),
    Badge.new(key: :second_opinion, threshold: 25, stat: :votes),
    Badge.new(key: :referee, threshold: 100, stat: :votes),
    Badge.new(key: :founder, threshold: 1, stat: :first_cut)
  ].freeze

  # Ladder and count badges are worth nudging towards; the one-off marks
  # are not, they mark something done rather than something to chase.
  CHASED = %i[accepted votes notes_accepted districts weeks].freeze

  # `stats` is a hash of the counters above. Returns the badges earned, in
  # table order.
  def self.earned(stats)
    ALL.select { |b| stats.fetch(b.stat, 0) >= b.threshold }
  end

  # The nearest chased badge not yet earned and how far off it is, or nil.
  def self.next(stats)
    ALL.select { |b| CHASED.include?(b.stat) }
       .reject { |b| stats.fetch(b.stat, 0) >= b.threshold }
       .min_by { |b| b.threshold - stats.fetch(b.stat, 0) }
       &.then { |b| [ b, b.threshold - stats.fetch(b.stat, 0) ] }
  end

  # The counters, from a person's contributions and votes. Shared by users
  # and anonymous devices.
  def self.stats(contributions:, votes:)
    accepted = contributions.kept.status_accepted
    {
      accepted: accepted.count,
      homes_confirmed: accepted.where(kind: :confirm_address).count,
      reports_accepted: accepted.where(kind: %i[dispute_address missing_building boundary_move]).count,
      blocks_accepted: accepted.where(kind: :multi_occupancy).count,
      notes_accepted: accepted.where(kind: :delivery_note).count,
      districts: districts_of(accepted),
      weeks: contributions.kept.pluck(:created_at).map { |t| t.strftime("%G-%V") }.uniq.size,
      votes: votes.count,
      first_cut: contributions.kept.joins(:gazetteer_version).where(gazetteer_versions: { version: "0.1.0" }).exists? ? 1 : 0
    }
  end

  # Distinct district codes across a person's accepted contributions: a
  # building's district, or the first token of a place code.
  def self.districts_of(accepted)
    accepted.includes(:building).map { |c| c.building ? c.building.district_code : c.target_code.to_s.split(" ").first }
      .compact_blank.uniq.size
  end
end
