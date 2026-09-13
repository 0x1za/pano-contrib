require "test_helper"
require "vips"

class PhotoUploadTest < ActiveSupport::TestCase
  def upload(name, type)
    Rack::Test::UploadedFile.new(file_fixture(name), type)
  end

  test "strips every metadata block, including GPS, and re-encodes as JPEG" do
    original = Vips::Image.new_from_file(file_fixture("gate.jpg").to_s)
    assert_operator original.get_fields.grep(/GPS/).size, :>, 0, "the fixture carries a location"

    processed = PhotoUpload.call(upload("gate.jpg", "image/jpeg"))
    assert_equal "image/jpeg", processed.content_type
    stripped = Vips::Image.new_from_file(processed.file.path)
    assert_equal [], stripped.get_fields.grep(/exif|xmp|iptc|icc/), "no metadata survives"
    assert_equal [ 96, 64 ], [ stripped.width, stripped.height ], "a small photo keeps its size"
  end

  test "a large photo is scaled to fit 1600 px" do
    big = Tempfile.new([ "big", ".jpg" ])
    Vips::Image.black(4000, 3000).jpegsave(big.path)
    processed = PhotoUpload.call(Rack::Test::UploadedFile.new(big.path, "image/jpeg"))
    out = Vips::Image.new_from_file(processed.file.path)
    assert_equal [ 1600, 1200 ], [ out.width, out.height ]
  end

  test "refuses what is not a photo, whatever it claims to be" do
    error = assert_raises(PhotoUpload::Error) { PhotoUpload.call(upload("not-a-photo.txt", "image/jpeg")) }
    assert_match(/not a photo we can read/, error.message)
  end
end
