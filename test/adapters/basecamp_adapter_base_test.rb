# frozen_string_literal: true

require "test_helper"

# Base class for Basecamp adapter tests, handling common setup
class BasecampAdapterBaseTest < ActiveSupport::TestCase
  def setup
    # IMPORTANT: Set these environment variables before running tests for the first time
    # to record the VCR cassette.
    @account_id = ENV.fetch("BASECAMP_ACCOUNT_ID", "DUMMY_ACCOUNT_ID")
    @access_token = ENV.fetch("BASECAMP_ACCESS_TOKEN", "DUMMY_ACCESS_TOKEN")

    # Configure VCR specifically for Basecamp (filtering different credentials)
    # Note: Recording check needs to happen within VCR.use_cassette block
    VCR.configure do |config|
      config.filter_sensitive_data("<BASECAMP_ACCOUNT_ID>") { @account_id }
      config.filter_sensitive_data("<BASECAMP_ACCESS_TOKEN>") { @access_token }
      # Filter Authorization header
      config.filter_sensitive_data("<BASECAMP_AUTH_HEADER>") do |interaction|
        auth = interaction.request.headers["Authorization"]&.first
        if auth&.start_with?("Bearer ") && auth.split(" ", 2).last == @access_token
          "Bearer <FILTERED_TOKEN>"
        else
          auth
        end
      end
    end

    # Store original config options for restoration
    @original_basecamp_config_options = ActiveProject.configuration.adapter_config(:basecamp)&.options&.dup || {}

    ActiveProject.configure do |config|
      config.add_adapter :basecamp, account_id: @account_id, access_token: @access_token
    end

    # Initialize adapter using the new config structure via the helper
    @adapter = ActiveProject.adapter(:basecamp)
    # Clear memoized adapter instance in ActiveProject module
    ActiveProject.reset_adapters

    # Fetch context IDs needed for many tests
    setup_context_ids
  end

  def teardown
    # Clear memoized adapter instance again after teardown
    ActiveProject.reset_adapters
  end

  # Helper to fetch and store common test IDs from ENV
  def setup_context_ids
    @project_id = ENV.fetch("BASECAMP_TEST_PROJECT_ID", "41789030")
    @todolist_id = ENV.fetch("BASECAMP_TEST_TODOLIST_ID", "8514014894")
    @todo_id = ENV.fetch("BASECAMP_TEST_TODO_ID", "8514015012") # An existing todo ID for find/update/comment
  end
end
