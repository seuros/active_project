# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require "dotenv/load" # Load .env before environment
require_relative "dummy/config/environment"
require "rails/test_help"
require "vcr"
require "webmock/minitest"
require "mocha/minitest"

# VCR Configuration
# test/test_helper.rb  (or wherever your VCR config lives)
require "base64"

VCR.configure do |config|
  # ------------------------------------------------------------------
  # Cassette folder & driver
  # ------------------------------------------------------------------
  config.cassette_library_dir = File.expand_path("fixtures/vcr_cassettes", __dir__)
  config.hook_into :webmock

  # ------------------------------------------------------------------
  # Record mode / request matching
  #   :none  – CI/playback only
  #   :new_episodes – record new calls the first time and keep existing
  #   :all   – wipe + re-record every run (use sparingly)
  # ------------------------------------------------------------------
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method path body]
  }

  # ------------------------------------------------------------------
  # 1. Filter obvious tokens & usernames
  # ------------------------------------------------------------------
  {
    "<JIRA_API_TOKEN>" => ENV["JIRA_API_TOKEN"],
    "<JIRA_USERNAME>" => ENV["JIRA_USERNAME"],
    "<GITHUB_TOKEN>" => ENV["GITHUB_PROJECT_ACCESS_TOKEN"],
    "<GITHUB_OWNER>" => ENV["GITHUB_PROJECT_OWNER"],
    "<BASECAMP_ACCOUNT_ID>" => ENV["BASECAMP_ACCOUNT_ID"],
    "<TRELLO_API_KEY>" => ENV["TRELLO_API_KEY"],
    "<TRELLO_API_TOKEN>" => ENV["TRELLO_API_TOKEN"]
  }.each do |placeholder, value|
    next unless value && !value.empty?

    config.filter_sensitive_data(placeholder) { value }
  end

  # ------------------------------------------------------------------
  # 2.  Strip or mangle auth headers that VCR doesn’t catch by value
  # ------------------------------------------------------------------
  SENSITIVE_HEADERS = %w[
    Authorization
    Cookie
    X-Api-Key
  ].freeze

  config.before_record do |i|
    SENSITIVE_HEADERS.each do |h|
      i.request.headers.delete(h)
      i.response.headers.delete(h)
    end
  end
  
  # GitHub-specific filters
  config.filter_sensitive_data("<GITHUB_ACCESS_TOKEN>") { ENV["GITHUB_ACCESS_TOKEN"] || "DUMMY_GITHUB_TOKEN" }
  
  # Filter GitHub Bearer auth header
  config.filter_sensitive_data("<GITHUB_BEARER_AUTH>") do |interaction|
    next unless interaction.request.uri.include?("api.github.com")
    
    auth_header = interaction.request.headers["Authorization"]&.first
    if auth_header&.start_with?("Bearer ")
      "Bearer <GITHUB_ACCESS_TOKEN>"
    end
  end
  
  # Filter webhook secret
  config.filter_sensitive_data("<GITHUB_WEBHOOK_SECRET>") { ENV["GITHUB_WEBHOOK_SECRET"] || "DUMMY_WEBHOOK_SECRET" }

  # ------------------------------------------------------------------
  # 3.  Replace dynamic node-IDs / numbers so they never leak
  # ------------------------------------------------------------------
  DYNAMIC_PATTERNS = {
    /PVTI_[A-Za-z0-9]+/ => "<PVTI_ID>",
    /PROJECTV2_[A-Za-z0-9]+/ => "<PROJECT_NODE_ID>",
    /[A-Z]{2,10}-\d+/ => "<ISSUE_KEY>", # Jira keys
    /\b\d{10,}\b/ => "<BIG_INT>" # Unix-ish timestamps
  }.freeze

  config.before_record do |i|
    DYNAMIC_PATTERNS.each do |regex, placeholder|
      i.request.body&.gsub!(regex, placeholder)
      i.response.body&.gsub!(regex, placeholder)
    end
  end

  # ------------------------------------------------------------------
  # 4.  Collapse volatile headers so cassettes stay deterministic
  # ------------------------------------------------------------------
  VOLATILE_HEADERS = %w[
    X-RateLimit-Remaining
    X-RateLimit-Reset
    Date
  ].freeze

  config.before_record do |i|
    VOLATILE_HEADERS.each { |h| i.response.headers.delete(h) }
  end

  # ------------------------------------------------------------------
  # 5.  Special-case basic-auth for Jira (keeps your existing logic)
  # ------------------------------------------------------------------
  config.filter_sensitive_data("<JIRA_BASIC_AUTH>") do |interaction|
    next unless interaction.request.uri.include?(ENV["JIRA_SITE_URL"].to_s)

    auth_header = interaction.request.headers["Authorization"]&.first
    if auth_header&.start_with?("Basic ")
      # always replace the *whole* header value – no need to decode
      auth_header
    end
  end

  # Get record mode from env var or default to :new_episodes
  record_mode = ENV["VCR_RECORD_MODE"]&.to_sym || :new_episodes
  
  # Update the record mode if specified
  config.default_cassette_options[:record] = record_mode
end
