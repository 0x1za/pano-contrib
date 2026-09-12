# A batch of accepted contributions on its way into the next gazetteer
# cut. Draft: gathers what is accepted and unassigned. Exported: frozen as
# `changes.json` for `zoning --changes`. Applied: the cut was made and the
# diff tool's churn report is stored against it.
class Changeset < ApplicationRecord
  belongs_to :gazetteer_version
  belongs_to :exported_by, class_name: "User", optional: true
  has_many :contributions, dependent: :nullify

  enum :status, { draft: 0, exported: 1, applied: 2 }, prefix: true

  scope :recent, -> { order(created_at: :desc) }

  # What this gazetteer version's accepted, unassigned contributions would
  # export. One draft per version; calling again refreshes it.
  def self.draft!(version)
    draft = status_draft.find_or_create_by!(gazetteer_version: version)
    draft.gather!
    draft
  end

  def gather!
    raise ArgumentError, "only a draft gathers" unless status_draft?
    transaction do
      Contribution.kept.status_accepted.where(gazetteer_version: gazetteer_version, changeset_id: nil).update_all(changeset_id: id)
      refresh!
    end
  end

  # Freezes the export. The JSON is stored in `export` so the file
  # downloaded later is byte-for-byte what zoning consumed.
  def export!(by: nil)
    raise ArgumentError, "already exported" unless status_draft?
    transaction do
      refresh!
      update!(status: :exported, exported_at: Time.current, exported_by: by)
    end
  end

  def applied!(version:, churn:)
    raise ArgumentError, "export first" unless status_exported?
    update!(status: :applied, applied_in_version: version, applied_at: Time.current, churn: churn)
  end

  # The `changes.json` contract with zoning (docs/contributions-plan.md §8).
  def build_changes
    export = Export.new(contributions.kept.status_accepted.includes(:building))
    {
      "gazetteer" => gazetteer_version.version,
      "generated_by" => gazetteer_version.sha256,
      "names" => export.names,
      "seeds" => [],
      "buildings" => export.buildings,
      "sub_addresses" => export.sub_addresses,
      "disputed_cells" => export.disputed_cells
    }
  end

  def to_json_file
    JSON.pretty_generate(export) + "\n"
  end

  private
    def refresh!
      built = build_changes
      update!(export: built, summary: {
        "contributions" => contributions.kept.status_accepted.count,
        "names" => built["names"].size,
        "buildings" => built["buildings"].size,
        "sub_addresses" => built["sub_addresses"].values.sum(&:size),
        "disputed_cells" => built["disputed_cells"].size
      })
    end

    # Pure: accepted contributions in, the four sections out. The latest
    # accepted answer wins for a name; sub-addresses accumulate per point.
    class Export
      def initialize(contributions)
        @contributions = contributions.sort_by(&:reviewed_at)
      end

      def names
        @contributions.select { |c| c.kind_dispute_district? || c.kind_name_place? }
          .to_h { |c| [ c.target_code, c.name ] }
      end

      def buildings
        @contributions.select(&:kind_missing_building?)
          .map { |c| { "lat" => c.lat, "lng" => c.lng, "note" => c.payload["note"].to_s } }
      end

      def sub_addresses
        @contributions.select { |c| c.kind_confirm_address? && c.sub_address.present? }
          .group_by { |c| c.building.address }
          .transform_values { |cs| cs.map(&:sub_address).uniq.sort }
          .sort.to_h
      end

      def disputed_cells
        @contributions.select(&:kind_boundary_move?)
          .flat_map { |c| Array(c.payload["cells"]).map { |cell| { "cell" => cell, "from" => c.payload["from"].to_s, "to" => c.payload["to"].to_s } } }
      end
    end
end
