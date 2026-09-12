require "csv"
require "digest"

# Imports a published gazetteer directory into places and buildings. Mirrors
# the Rust reader's rule: every file named in SHA256SUMS is hashed before
# anything is parsed, and a mismatch refuses the directory.
class GazetteerImport
  FILES = %w[units.csv boundaries.geojson meta.toml PROVENANCE.md buildings.csv].freeze
  BATCH = 5_000

  class Error < StandardError; end

  attr_reader :dir

  def initialize(dir)
    @dir = Pathname(dir)
  end

  def call
    sums = verify!
    meta = parse_meta
    version = GazetteerVersion.find_by(sha256: Digest::SHA256.hexdigest(sums))
    return version if version

    GazetteerVersion.transaction do
      version = GazetteerVersion.create!(
        version: meta.fetch("version"), sha256: Digest::SHA256.hexdigest(sums), area: meta.fetch("area"),
        names: meta.fetch("names", {}), imported_at: Time.current
      )
      import_places(version)
      import_buildings(version)
      version.update!(units_count: version.places.tier_unit.count, buildings_count: version.buildings.count)
      version
    end
  end

  private
    def verify!
      sums = dir.join("SHA256SUMS").read
      listed = sums.lines.to_h { |l| h, n = l.split(/\s+/, 2); [ n.to_s.strip, h ] }
      FILES.each do |name|
        want = listed[name] or raise Error, "#{name} is not listed in SHA256SUMS"
        got = Digest::SHA256.file(dir.join(name)).hexdigest
        raise Error, "hash mismatch for #{name}: SHA256SUMS says #{want}, file is #{got}" unless got == want
      end
      sums
    end

    # meta.toml is small and flat; a tiny parser avoids a gem for one file.
    # Handles `key = "value"`, `key = 123` and one level of `[section]`,
    # with `[names]` mapping district codes to names.
    def parse_meta
      meta = { "names" => {} }
      section = nil
      dir.join("meta.toml").each_line do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        if (m = line.match(/\A\[(.+)\]\z/))
          section = m[1]
          next
        end
        next unless (m = line.match(/\A"?([^"=]+?)"?\s*=\s*(.+)\z/))
        key, value = m[1].strip, m[2].strip
        value = value[1..-2] if value.start_with?('"') && value.end_with?('"')
        if section == "names"
          meta["names"][key] = value
        elsif section.nil?
          meta[key] = value =~ /\A\d+\z/ ? value.to_i : value
        end
      end
      meta
    end

    def import_places(version)
      units = Hash.new { |h, k| h[k] = { structures: 0, lats: [], lngs: [] } }
      geo = JSON.parse(dir.join("boundaries.geojson").read)
      geo.fetch("features").each do |f|
        p = f.fetch("properties")
        units[p.fetch("code")] = { structures: p.fetch("structures"), lats: [ p.fetch("centroid_lat") ], lngs: [ p.fetch("centroid_lng") ] }
      end
      rows = units.map do |code, u|
        district, inward = code.split(" ")
        { id: SecureRandom.uuid, gazetteer_version_id: version.id, tier: Place.tiers[:unit], code: code,
          parent_code: "#{district} #{inward[0]}", name: nil,
          centroid_lat: u[:lats].sum / u[:lats].size, centroid_lng: u[:lngs].sum / u[:lngs].size, structures: u[:structures] }
      end
      sectors = aggregate(rows, :sector, version)
      districts = aggregate(rows, :district, version)
      (rows + sectors + districts).each_slice(BATCH) { |slice| Place.insert_all!(slice) }
    end

    # Sectors and districts as structure-weighted means of their units.
    def aggregate(unit_rows, tier, version)
      groups = unit_rows.group_by { |r| tier == :sector ? r[:parent_code] : r[:code].split(" ").first }
      groups.map do |code, rows|
        weight = rows.sum { |r| r[:structures] }.to_f
        lat, lng = if weight > 0
          [ rows.sum { |r| r[:centroid_lat] * r[:structures] } / weight, rows.sum { |r| r[:centroid_lng] * r[:structures] } / weight ]
        else
          [ rows.sum { |r| r[:centroid_lat] } / rows.size, rows.sum { |r| r[:centroid_lng] } / rows.size ]
        end
        { id: SecureRandom.uuid, gazetteer_version_id: version.id, tier: Place.tiers[tier], code: code,
          parent_code: (tier == :sector ? code.split(" ").first : nil),
          name: (tier == :district ? version.names[code] : nil),
          centroid_lat: lat, centroid_lng: lng, structures: weight.to_i }
      end
    end

    def import_buildings(version)
      batch = []
      CSV.foreach(dir.join("buildings.csv"), headers: true) do |row|
        batch << { id: SecureRandom.uuid, gazetteer_version_id: version.id, ingest_id: row["id"].to_i,
                   unit_code: row["code"], number: row["number"].to_i, lat: row["lat"].to_f, lng: row["lng"].to_f }
        if batch.size >= BATCH
          Building.insert_all!(batch)
          batch.clear
        end
      end
      Building.insert_all!(batch) if batch.any?
    end
end
