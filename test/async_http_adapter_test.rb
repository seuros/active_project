# frozen_string_literal: true

require "test_helper"

# Test that async_http adapter is properly registered and can be configured.
# Note: Real async HTTP tests with network calls are problematic with VCR/WebMock
# because Minitest parallel threads conflict with Async's event loop.
class AsyncHttpAdapterTest < ActiveSupport::TestCase
  test "async_http adapter is registered with Faraday" do
    # Verify the adapter is available
    assert Faraday::Adapter.lookup_middleware(:async_http),
           "async_http adapter should be registered"
  end

  test "async_http adapter can be selected via environment variable" do
    original = ENV["AP_DEFAULT_ADAPTER"]
    ENV["AP_DEFAULT_ADAPTER"] = "async_http"

    # Build a minimal connection to test adapter selection
    connection = Faraday.new(url: "https://example.com") do |conn|
      conn.request :retry
      conn.response :raise_error
      default_adapter = ENV.fetch("AP_DEFAULT_ADAPTER", "net_http").to_sym
      conn.adapter default_adapter
    end

    # Verify async_http was selected - adapter returns a Handler with klass attribute
    adapter_handler = connection.builder.adapter
    assert_equal Async::HTTP::Faraday::Adapter, adapter_handler.klass,
                 "Connection should use async_http adapter when AP_DEFAULT_ADAPTER is set"
  ensure
    if original
      ENV["AP_DEFAULT_ADAPTER"] = original
    else
      ENV.delete("AP_DEFAULT_ADAPTER")
    end
  end

  test "default adapter is net_http when env not set" do
    original = ENV["AP_DEFAULT_ADAPTER"]
    ENV.delete("AP_DEFAULT_ADAPTER")

    connection = Faraday.new(url: "https://example.com") do |conn|
      conn.request :retry
      conn.response :raise_error
      default_adapter = ENV.fetch("AP_DEFAULT_ADAPTER", "net_http").to_sym
      conn.adapter default_adapter
    end

    adapter_handler = connection.builder.adapter
    assert_equal Faraday::Adapter::NetHttp, adapter_handler.klass,
                 "Connection should default to net_http when AP_DEFAULT_ADAPTER is not set"
  ensure
    ENV["AP_DEFAULT_ADAPTER"] = original if original
  end

  test "async_http adapter class is properly defined" do
    # Verify the adapter class exists and has the expected interface
    adapter_class = Async::HTTP::Faraday::Adapter
    assert adapter_class < Faraday::Adapter,
           "Async::HTTP::Faraday::Adapter should inherit from Faraday::Adapter"

    # Verify connection can be built with the adapter (without making requests)
    connection = Faraday.new(url: "https://example.com") do |conn|
      conn.adapter :async_http
    end

    assert_kind_of Faraday::Connection, connection
    assert_equal Async::HTTP::Faraday::Adapter, connection.builder.adapter.klass
  end
end
