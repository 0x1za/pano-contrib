# Residents who recognised the district and pointed at their building
# become hand-verified conformance vectors: unit code → cells → sector →
# district, in the shape fixtures/conformance/*.json uses on the Rust
# side. Cells come from the pano API, since the app imports boundaries,
# not cells.
class FieldFixture
  def initialize(survey)
    @survey = survey
  end

  def to_h
    units = @survey.responses.where(recognises: true).includes(:building).filter_map(&:building).map(&:unit_code).uniq.sort
    {
      "gazetteer" => "gazetteer/v#{@survey.gazetteer_version.version}",
      "status" => "hand-verified",
      "generated_by" => @survey.gazetteer_version.sha256,
      "survey" => { "district" => @survey.target_code, "name" => @survey.display_name, "residents" => @survey.responses.count, "closed_at" => @survey.closed_at&.iso8601 },
      "vectors" => units.filter_map { |unit| vector(unit) }
    }
  end

  def to_json_file
    JSON.pretty_generate(to_h) + "\n"
  end

  private
    def vector(unit)
      status, body = PanoApi.resolve(unit)
      return nil unless status == 200
      { "code" => body["code"], "cells" => body["cells"], "parent" => body.dig("parents", "sector"), "district" => body.dig("parents", "district") }
    end
end
