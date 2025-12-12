# frozen_string_literal: true

require "test_helper"

# Base class for Fizzy adapter tests, handling common setup
class FizzyAdapterBaseTest < ActiveSupport::TestCase
  # Use deterministic values instead of Time.now.to_i for VCR matching
  TIMESTAMP_PLACEHOLDER = "<BIG_INT>"

  def setup
    # Default values match the recorded VCR cassettes for CI playback.
    # Set ENV vars to record new cassettes against a live Fizzy instance.
    @account_slug = ENV.fetch("FIZZY_ACCOUNT_SLUG", "897362094")
    @access_token = ENV.fetch("FIZZY_ACCESS_TOKEN", "test_token_for_vcr_playback")
    @base_url = ENV.fetch("FIZZY_BASE_URL", "http://fizzy.localhost:3006")

    # Configure VCR specifically for Fizzy
    # NOTE: We only filter sensitive data in response bodies, not in URIs
    # This allows cassettes to replay correctly with matching URIs
    VCR.configure do |config|
      # Filter access token from response bodies only (not URIs)
      config.filter_sensitive_data("<FIZZY_ACCESS_TOKEN>") { @access_token }

      # Filter Authorization header
      config.filter_sensitive_data("<FIZZY_AUTH_HEADER>") do |interaction|
        auth = interaction.request.headers["Authorization"]&.first
        if auth&.start_with?("Bearer ") && auth.split(" ", 2).last == @access_token
          "Bearer <FILTERED_TOKEN>"
        else
          auth
        end
      end
    end

    # Store original config options for restoration
    @original_fizzy_config_options = ActiveProject.configuration.adapter_config(:fizzy)&.options&.dup || {}

    # Clear memoized adapter instance in ActiveProject module first
    ActiveProject.reset_adapters

    ActiveProject.configure do |config|
      config.add_adapter :fizzy,
                         account_slug: @account_slug,
                         access_token: @access_token,
                         base_url: @base_url
    end

    # Initialize adapter using the new config structure via the helper
    @adapter = ActiveProject.adapter(:fizzy)

    # Fetch context IDs needed for many tests
    setup_context_ids
  end

  def teardown
    # Clear memoized adapter instance again after teardown
    ActiveProject.reset_adapters
  end

  # Helper to fetch and store common test IDs from ENV
  # Default values match the recorded VCR cassettes
  def setup_context_ids
    @board_id = ENV.fetch("FIZZY_TEST_BOARD_ID", "03f7agcrvnqk92t28j6back5t")
    @card_number = ENV.fetch("FIZZY_TEST_CARD_NUMBER", "1")
    @column_id = ENV.fetch("FIZZY_TEST_COLUMN_ID", "DUMMY_COLUMN_ID")
  end
end
