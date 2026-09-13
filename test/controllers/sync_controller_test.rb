require "test_helper"

class SyncControllerTest < ActionDispatch::IntegrationTest
  test "push applies a batch for this device and answers per mutation" do
    post sync_push_path, params: { mutations: [
      { mutationId: "a1", type: "contribute", args: { kind: "confirm_address", address: "LS1 1CC 2" } },
      { mutationId: "a2", type: "contribute", args: { kind: "delivery_note", address: "LS1 1CC 1", note: "Blue gate" } },
      { mutationId: "a3", type: "contribute", args: { kind: "confirm_address", address: "LS0 0AA 1" } }
    ] }, as: :json
    assert_response :success
    results = response.parsed_body["results"]
    assert_equal %w[accepted accepted rejected], results.map { |r| r["status"] }
    assert_equal %w[a1 a2 a3], results.map { |r| r["mutationId"] }
    assert cookies[:pano_device].present?, "the batch minted this browser's device"

    post sync_push_path, params: { mutations: [ { mutationId: "a1", type: "contribute", args: { kind: "confirm_address", address: "LS1 1CC 2" } } ] }, as: :json
    assert_equal "duplicate", response.parsed_body["results"].first["status"]
  end
end
