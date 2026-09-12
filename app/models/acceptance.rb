# The auto-acceptance rules from the plan, as one pure function so the
# whole table can be tested without a database. Every acceptance is by
# vote count or by a named moderator; votes alone never reject.
module Acceptance
  # Votes are counted; age is how long the contribution has been pending.
  Tally = Data.define(:agree, :disagree, :age) do
    def unopposed? = disagree.zero?
  end

  MODERATOR_ONLY = %w[dispute_district dispute_address missing_building boundary_move].freeze

  # Returns :accept or :pending.
  def self.decide(kind, tally)
    case kind
    when "confirm_district" then tally.agree >= 5 ? :accept : :pending
    when "confirm_address" then tally.agree >= 3 ? :accept : :pending
    when "name_place" then tally.agree >= 5 && tally.unopposed? ? :accept : :pending
    when "delivery_note"
      tally.agree >= 1 || (tally.age >= 30.days && tally.unopposed?) ? :accept : :pending
    else :pending
    end
  end

  def self.moderator_only?(kind)
    MODERATOR_ONLY.include?(kind)
  end
end
