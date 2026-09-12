require "test_helper"

class GazetteerImportTest < ActiveSupport::TestCase
  DIR = Rails.root.join("test/fixtures/files/gazetteer/v0.0.0-test")

  test "imports units, sectors, districts and buildings" do
    version = GazetteerImport.new(DIR).call
    assert_equal "0.0.0-test", version.version
    assert_equal "LS", version.area
    assert_equal({ "LS1" => "Kabulonga", "LS3" => "Kanyama" }, version.names)
    assert_equal 3, version.places.tier_unit.count
    assert_equal %w[LS1\ 1 LS3\ 1], version.places.tier_sector.order(:code).pluck(:code)
    assert_equal %w[LS1 LS3], version.places.tier_district.order(:code).pluck(:code)
    assert_equal "Kabulonga", version.places.find_by(code: "LS1").name
    assert_equal 60, version.places.find_by(code: "LS1").structures, "district structures are the sum of its units"
    assert_equal 4, version.buildings.count
    assert_equal "LS1 1CC 2", version.buildings.find_by(ingest_id: 2).address
    assert_equal 3, version.units_count
    assert_equal 4, version.buildings_count
  end

  test "importing the same directory twice returns the same version" do
    first = GazetteerImport.new(DIR).call
    assert_no_difference -> { GazetteerVersion.count } do
      assert_equal first, GazetteerImport.new(DIR).call
    end
  end

  test "refuses a directory whose hashes do not match" do
    Dir.mktmpdir do |tmp|
      FileUtils.cp_r(DIR.to_s + "/.", tmp)
      File.write(File.join(tmp, "buildings.csv"), "id,lat,lng,code,number\n9,0,0,LS1 1CC,9\n")
      error = assert_raises(GazetteerImport::Error) { GazetteerImport.new(tmp).call }
      assert_match(/hash mismatch for buildings.csv/, error.message)
      assert_nil GazetteerVersion.find_by(version: "0.0.0-test"), "nothing is written before verification passes"
    end
  end
end
