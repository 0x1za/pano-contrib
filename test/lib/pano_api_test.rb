require "test_helper"

class PanoApiTest < ActiveSupport::TestCase
  Response = Struct.new(:code, :body, :headers) do
    def [](name) = headers[name]
  end

  setup do
    @cache, @transport = Rails.cache, PanoApi.transport
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache, PanoApi.transport = @cache, @transport }

  test "an answer is cached under its ETag and revalidated with If-None-Match" do
    calls = []
    fresh = Response.new("200", '{"code":"LS1 1CC"}', { "ETag" => '"abc"' })
    not_modified = Response.new("304", "", {})
    PanoApi.transport = ->(uri, etag) { calls << [ uri.path, etag ]; calls.size == 1 ? fresh : not_modified }

    assert_equal [ 200, { "code" => "LS1 1CC" } ], PanoApi.resolve("LS1 1CC")
    assert_equal [ 200, { "code" => "LS1 1CC" } ], PanoApi.resolve("LS1 1CC")
    assert_equal [ [ "/resolve/LS1%201CC", nil ], [ "/resolve/LS1%201CC", '"abc"' ] ], calls
  end

  test "a 404 is an answer, anything else is an error" do
    PanoApi.transport = ->(*) { Response.new("404", '{"nearest":"LS1 1CC"}', { "ETag" => '"abc"' }) }
    assert_equal [ 404, { "nearest" => "LS1 1CC" } ], PanoApi.encode(lat: 0, lng: 0)

    PanoApi.transport = ->(*) { Response.new("500", "", {}) }
    error = assert_raises(PanoApi::Error) { PanoApi.meta }
    assert_match(/returned 500/, error.message)
  end
end
