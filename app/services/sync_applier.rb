# Contributions made offline arrive here in a batch, each with the
# mutation id the phone minted. Applying is idempotent on
# (device, mutation id): a replayed batch answers "duplicate" for what it
# already has and never stores it twice. Wire vocabulary must stay in
# lockstep with app/javascript/sync/client.js.
class SyncApplier
  CONTRIBUTE = "contribute"

  ACCEPTED = "accepted"
  DUPLICATE = "duplicate"
  REJECTED = "rejected"

  # The offline form is text-only: an address the person already knows.
  OFFLINE_KINDS = %w[confirm_address delivery_note dispute_address].freeze

  Result = Data.define(:mutation_id, :status, :reason, :contribution_id) do
    def to_h
      { mutationId: mutation_id, status: status, reason: reason, contributionId: contribution_id }.compact
    end
  end

  def initialize(device:, user:, gazetteer:, mutations:)
    @device, @user, @gazetteer, @mutations = device, user, gazetteer, Array(mutations)
  end

  def call
    @mutations.map { |m| apply_one(m.to_h.stringify_keys) }
  end

  private
    def apply_one(mutation)
      id = mutation["mutationId"].to_s
      return Result.new(mutation_id: id, status: REJECTED, reason: "mutation id missing", contribution_id: nil) if id.blank?
      if (existing = Contribution.find_by(device: @device, mutation_id: id))
        return Result.new(mutation_id: id, status: DUPLICATE, reason: nil, contribution_id: existing.id)
      end
      return Result.new(mutation_id: id, status: REJECTED, reason: "unknown mutation type #{mutation["type"].inspect}", contribution_id: nil) unless mutation["type"] == CONTRIBUTE

      contribution = build(id, (mutation["args"] || {}).to_h.stringify_keys)
      if contribution.save
        contribution.reconsider!
        Result.new(mutation_id: id, status: ACCEPTED, reason: nil, contribution_id: contribution.id)
      elsif (dup = contribution.duplicate_of)
        Result.new(mutation_id: id, status: DUPLICATE, reason: "already said about #{dup.target_label}", contribution_id: dup.id)
      else
        Result.new(mutation_id: id, status: REJECTED, reason: contribution.errors.full_messages.to_sentence, contribution_id: nil)
      end
    rescue ActiveRecord::RecordNotUnique
      Result.new(mutation_id: id, status: DUPLICATE, reason: nil, contribution_id: Contribution.find_by(device: @device, mutation_id: id)&.id)
    end

    def build(id, args)
      kind = args["kind"].to_s
      building = resolve_building(args["address"].to_s)
      contribution = Contribution.new(
        kind: OFFLINE_KINDS.include?(kind) ? kind : nil,
        target_kind: :building, building: building, mutation_id: id,
        payload: args.slice("note", "sub", "reason").compact_blank,
        gazetteer_version: @gazetteer, device: @device, user: @user
      )
      contribution.errors.add(:kind, "must be one of #{OFFLINE_KINDS.join(", ")}") unless OFFLINE_KINDS.include?(kind)
      contribution.errors.add(:building, "#{args["address"].inspect} is not an address in this gazetteer") if building.nil?
      contribution.define_singleton_method(:save) { |*| errors.empty? && super() } if contribution.errors.any?
      contribution
    end

    # `LS1 1JC 17`, with or without a `/home` suffix: the unit and number
    # name the building; the home, if any, rides in the payload.
    def resolve_building(address)
      return nil if @gazetteer.nil?
      point, _home = address.strip.upcase.split("/", 2)
      unit, number = point.to_s.strip.rpartition(" ").values_at(0, 2)
      return nil if unit.blank? || number !~ /\A\d+\z/
      @gazetteer.buildings.find_by(unit_code: unit.squeeze(" "), number: number.to_i)
    end
end
