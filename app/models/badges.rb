# What a contributor has earned, from counts alone, so the whole table can
# be tested without a database. Badges never expire and never subtract:
# they mark what someone did, not how they rank.
module Badges
  Badge = Data.define(:key, :threshold, :stat)

  ALL = [
    Badge.new(key: :first_step, threshold: 1, stat: :accepted),
    Badge.new(key: :neighbour, threshold: 10, stat: :accepted),
    Badge.new(key: :streetwise, threshold: 50, stat: :accepted),
    Badge.new(key: :cartographer, threshold: 1, stat: :names_accepted),
    Badge.new(key: :watchman, threshold: 1, stat: :disputes_accepted),
    Badge.new(key: :landlord, threshold: 1, stat: :homes_accepted),
    Badge.new(key: :voter, threshold: 25, stat: :votes)
  ].freeze

  # `stats` is a hash of the counters above. Returns the badges earned, in
  # table order.
  def self.earned(stats)
    ALL.select { |b| stats.fetch(b.stat, 0) >= b.threshold }
  end

  # The nearest counting badge not yet earned and how far off it is, or
  # nil. The one-off badges (a name, a report, a shared building) are not
  # nudged towards: they mark something done, not something to chase.
  def self.next(stats)
    ALL.select { |b| b.threshold > 1 || b.stat == :accepted }
       .reject { |b| stats.fetch(b.stat, 0) >= b.threshold }
       .min_by { |b| b.threshold - stats.fetch(b.stat, 0) }
       &.then { |b| [ b, b.threshold - stats.fetch(b.stat, 0) ] }
  end
end
