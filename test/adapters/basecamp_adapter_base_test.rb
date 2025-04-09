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
    # Restore original config options after each test
    ActiveProject.configure do |config|
      if @original_basecamp_config_options.any?
        config.add_adapter :basecamp, @original_basecamp_config_options
      else
        config.add_adapter :basecamp, {} # Reset if no original
      end
    end
    # Clear memoized adapter instance again after teardown
    ActiveProject.reset_adapters
  end


  # Helper to fetch and store common test IDs from ENV
  def setup_context_ids
    @project_id = ENV.fetch("BASECAMP_TEST_PROJECT_ID", nil)
    @todolist_id = ENV.fetch("BASECAMP_TEST_TODOLIST_ID", nil)
    @todo_id = ENV.fetch("BASECAMP_TEST_TODO_ID", nil) # An existing todo ID for find/update/comment
  end

  # Helper to skip tests if essential credentials or IDs are missing
  def skip_if_missing_credentials_or_ids(needs_project: false, needs_todolist: false, needs_todo: false)
    if @account_id.include?("DUMMY") || @access_token.include?("DUMMY")
      skip("Set BASECAMP_ACCOUNT_ID and BASECAMP_ACCESS_TOKEN environment variables.")
    end
    if needs_project && !@project_id
      skip("Set BASECAMP_TEST_PROJECT_ID environment variable.")
    end
    if needs_todolist && !@todolist_id
      skip("Set BASECAMP_TEST_TODOLIST_ID environment variable.")
    end
    if needs_todo && !@todo_id
      skip("Set BASECAMP_TEST_TODO_ID environment variable.")
    end
  end
end
