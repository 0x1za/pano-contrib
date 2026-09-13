require "test_helper"

class ApiControllerTest < ActionDispatch::IntegrationTest
  setup { @transport = ApiProxy.transport }
  teardown { ApiProxy.transport = @transport }

  test "forwards a read route with its query and the headers that matter" do
    seen = nil
    ApiProxy.transport = ->(uri, headers) { seen = [ uri, headers ]; ApiProxy::Response.new(status: 200, headers: { "Content-Type" => "application/json", "ETag" => '"g"' }, body: '{"code":"LS1 1CC"}') }
    get "/api/resolve/LS1%201CC?x=1", headers: { "If-None-Match" => '"old"', "Accept" => "application/json" }
    assert_response :success
    assert_equal "http://127.0.0.1:8080/resolve/LS1%201CC?x=1", seen[0].to_s, "the space goes back out encoded"
    assert_equal({ "If-None-Match" => '"old"', "Accept" => "application/json" }, seen[1])
    assert_equal '"g"', response.headers["ETag"]
    assert_equal "LS1 1CC", response.parsed_body["code"]
    get "/api/resolve/LS1%201CC?x=1", headers: { "If-None-Match" => '"g"' }
    assert_response :not_modified, "a matching ETag is answered with 304, as direct"
  end

  test "range requests for the tiles archive come back partial" do
    ApiProxy.transport = ->(_uri, headers) { ApiProxy::Response.new(status: 206, headers: { "Content-Type" => "application/octet-stream", "Content-Range" => "bytes 0-6/100", "Accept-Ranges" => "bytes" }, body: headers["Range"] == "bytes=0-6" ? "PMTiles" : "wrong") }
    get "/api/tiles/pano.pmtiles", headers: { "Range" => "bytes=0-6" }
    assert_response :partial_content
    assert_equal "bytes 0-6/100", response.headers["Content-Range"]
    assert_equal "PMTiles", response.body
  end

  test "only the API's read routes are forwarded" do
    ApiProxy.transport = ->(*) { flunk "must not be called" }
    get "/api/admin/anything"
    assert_response :not_found
  end

  test "an unreachable API is a bad gateway with a reason" do
    ApiProxy.transport = ->(*) { raise ApiProxy::Error, "pano API unreachable at http://127.0.0.1:8080: refused" }
    get "/api/meta"
    assert_response :bad_gateway
    assert_equal "api_unreachable", response.parsed_body["error"]
  end
end
