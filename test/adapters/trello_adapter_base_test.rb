# frozen_string_literal: true

require "test_helper"
require "webmock/minitest" # Required for stub_request

# Base class for Trello adapter tests, handling common setup and teardown.
class TrelloAdapterBaseTest < ActiveSupport::TestCase
  def setup
    # IMPORTANT: Set these environment variables before running tests for the first time
    # to record the VCR cassette.
    @api_key = ENV.fetch("TRELLO_API_KEY", "DUMMY_TRELLO_KEY")
    @api_token = ENV.fetch("TRELLO_API_TOKEN", "DUMMY_TRELLO_TOKEN")

    # Basic check to prevent running tests without real credentials when recording
    if VCR.current_cassette&.recording? && (@api_key.include?("DUMMY") || @api_token.include?("DUMMY"))
      # skip("Set TRELLO_API_KEY and TRELLO_API_TOKEN environment variables to record VCR cassettes.")
    end

    # Configure VCR specifically for Trello (filtering different credentials)
    VCR.configure do |config|
      config.filter_sensitive_data("<TRELLO_API_KEY>") { @api_key }
      config.filter_sensitive_data("<TRELLO_API_TOKEN>") { @api_token }
    end

    # Store original config options for restoration
    @original_trello_config_options = ActiveProject.configuration.adapter_config(:trello)&.options&.dup || {}

    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: @api_key, api_token: @api_token do |trello_config|
        # Default empty mappings, tests will override if needed
        trello_config.status_mappings = {}
      end
    end

    # Initialize adapter using the new config structure via the helper
    # This ensures the adapter gets the config object correctly
    @adapter = ActiveProject.adapter(:trello)

    # Clear memoized adapter instance in ActiveProject module to ensure
    # re-initialization picks up config changes within tests
    ActiveProject.reset_adapters
  end

  def teardown
    # Restore original config options after each test
    ActiveProject.configure do |config|
      # Use the block syntax if the original config was a TrelloConfiguration
      # Otherwise, just pass the options hash
      if @original_trello_config_options.any?
        # Check if original config had specific Trello settings (like status_mappings)
        # This logic might need refinement depending on how complex configs get
        original_mappings = @original_trello_config_options.delete(:status_mappings)
        if original_mappings
          config.add_adapter :trello, @original_trello_config_options do |trello_config|
            trello_config.status_mappings = original_mappings
          end
        else
          config.add_adapter :trello, @original_trello_config_options
        end
      else
        # If no original config, potentially remove the adapter config entirely
        # For simplicity, we'll just ensure it's reset to empty options if needed
        config.add_adapter :trello, {}
      end
    end
    # Clear memoized adapter instance again after teardown
    ActiveProject.reset_adapters
    WebMock.reset! # Reset WebMock stubs
  end

  private

  # Helper to skip tests if credentials are dummy values (useful for tests needing real interaction)
  def skip_if_missing_credentials
    nil unless @api_key.include?("DUMMY") || @api_token.include?("DUMMY")
    # skip("Set TRELLO_API_KEY and TRELLO_API_TOKEN environment variables for this test.")
  end
end
