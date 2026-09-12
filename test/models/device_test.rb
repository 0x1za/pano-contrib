require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  test "issue! stores only a digest and returns the raw token once" do
    device, raw = Device.issue!
    assert_equal 32, raw.length
    assert_equal Digest::SHA256.hexdigest(raw), device.token_digest
    assert_equal device, Device.find_by_token(raw)
    assert_nil Device.find_by_token("not-a-token")
    assert_nil Device.find_by_token(nil)
  end
end
