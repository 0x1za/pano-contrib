require "test_helper"

class ContributionPhotoTest < ActiveSupport::TestCase
  def photo
    Rack::Test::UploadedFile.new(file_fixture("gate.jpg"), "image/jpeg")
  end

  test "a delivery note may carry a stripped photo, private until accepted" do
    c = Contribution.new(kind: :delivery_note, target_kind: :building, building: buildings(:one), payload: { "note" => "Green gate" },
                         gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    c.photo_upload = photo
    assert c.save, c.errors.full_messages.to_sentence
    assert c.photo.attached?
    assert_equal "image/jpeg", c.photo.content_type
    assert_not c.photo_public?
    c.accept!(by: users(:moderator))
    assert c.reload.photo_public?
  end

  test "a confirmation does not take a photo" do
    c = Contribution.new(kind: :confirm_address, target_kind: :building, building: buildings(:two),
                         gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    c.photo_upload = photo
    assert_not c.valid?
    assert_includes c.errors[:photo], "does not go with this kind of contribution"
  end

  test "a bad file is a validation error, not an exception" do
    c = Contribution.new(kind: :delivery_note, target_kind: :building, building: buildings(:one), payload: { "note" => "Green gate" },
                         gazetteer_version: gazetteer_versions(:current), device: devices(:other))
    c.photo_upload = Rack::Test::UploadedFile.new(file_fixture("not-a-photo.txt"), "image/jpeg")
    assert_not c.valid?
    assert_match(/not a photo we can read/, c.errors[:photo].first)
    assert_not c.photo.attached?
  end
end
