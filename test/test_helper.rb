# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "dotenv/load" # Load .env before environment
require_relative "dummy/config/environment"
require "rails/test_help"
require "vcr"
require "webmock/minitest" # Or :rspec if using RSpec
require "mocha/minitest"   # Added for stubbing
require_relative "../lib/active_project/errors" # Explicitly require custom errors

# VCR Configuration
VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("fixtures/vcr_cassettes", __dir__)
  config.hook_into :webmock

  # Optional: Filter sensitive data like API tokens or passwords
  # Replace 'YOUR_JIRA_API_TOKEN' and 'YOUR_JIRA_USERNAME' with actual values or ENV vars if needed for filtering
  # Ensure these placeholders match how you might provide credentials during tests
  config.filter_sensitive_data("<JIRA_API_TOKEN>") { ENV["JIRA_API_TOKEN"] || "DUMMY_JIRA_API_TOKEN" }
  config.filter_sensitive_data("<JIRA_USERNAME>") { ENV["JIRA_USERNAME"] || "DUMMY_JIRA_USERNAME" }

  # Filter the Basic Auth header
  # This creates a placeholder based on the username and token being filtered
  config.filter_sensitive_data("<JIRA_BASIC_AUTH>") do |interaction|
    # Only filter if the request URI matches the Jira site URL
    next unless interaction.request.uri.include?(ENV["JIRA_SITE_URL"] || "DUMMY_JIRA_SITE")

    auth_header = interaction.request.headers["Authorization"]&.first
    if auth_header&.start_with?("Basic ")
      # Decode, check if it matches filtered credentials, then return placeholder
      # This is a simplified example; real implementation might need more robust checking
      decoded = Base64.decode64(auth_header.split(" ", 2).last)
      username, token = decoded.split(":", 2)
      if username == (ENV["JIRA_USERNAME"] || "DUMMY_JIRA_USERNAME") && token == (ENV["JIRA_API_TOKEN"] || "DUMMY_JIRA_API_TOKEN")
        "Basic <ENCODED_JIRA_CREDENTIALS>" # Placeholder for the encoded string
      else
        auth_header # Return original if it doesn't match
      end
    end
  end

  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method path body]
  }
end
