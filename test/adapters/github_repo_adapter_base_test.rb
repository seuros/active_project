# frozen_string_literal: true

require "test_helper"
require "active_project/adapters/github_repo_adapter"

# Base class for GitHub Adapter tests, handling common setup and teardown.
class GithubRepoAdapterBaseTest < ActiveSupport::TestCase
  # Define fixed values for deterministic VCR recording
  FIXED_TEST_REPO_OWNER = "aviflombaum"
  FIXED_TEST_REPO_NAME = "test-repo"
  FIXED_TEST_ISSUE_TITLE = "Test Issue via ActiveProject"

  def setup
    @owner = ENV.fetch("GITHUB_OWNER", FIXED_TEST_REPO_OWNER)
    @repo = ENV.fetch("GITHUB_REPO", FIXED_TEST_REPO_NAME)
    @access_token = ENV.fetch("GITHUB_ACCESS_TOKEN", "DUMMY_GITHUB_TOKEN")
    @webhook_secret = ENV.fetch("GITHUB_WEBHOOK_SECRET", "DUMMY_WEBHOOK_SECRET")

    if VCR.current_cassette&.recording? && @access_token.include?("DUMMY")
      skip("Set GITHUB_ACCESS_TOKEN environment variable to record VCR cassettes.")
    end

    @original_github_config_options = ActiveProject.configuration.adapter_config(:github_repo)&.options&.dup || {}

    ActiveProject.configure do |config|
      config.add_adapter :github_repo, {
        owner: @owner,
        repo: @repo,
        access_token: @access_token,
        webhook_secret: @webhook_secret
      }
    end

    @adapter = ActiveProject.adapter(:github_repo)

    # Store the repository info (which serves as our "project" in ActiveProject terms)
    @project_id = @repo
    @project_full_name = "#{@owner}/#{@repo}"

    # Reset adapter registry to ensure clean state
    ActiveProject.reset_adapters
  end

  def teardown
    ActiveProject.configure do |config|
      if @original_github_config_options.any?
        config.add_adapter :github_repo, @original_github_config_options
      else
        # Use minimal valid config for teardown
        config.add_adapter :github_repo, {
          owner: "dummy",
          repo: "dummy",
          access_token: "ghp_1234567890123456789012345678901234567890"
        }
      end
    end

    ActiveProject.reset_adapters
  end

  # Helper to create a test issue in GitHub repo
  # Can be used by individual tests that need an issue to work with
  def create_test_issue(title_suffix = "")
    issue = nil
    timestamp = Time.now.to_i
    title = "#{FIXED_TEST_ISSUE_TITLE} #{title_suffix} #{timestamp}"

    cassette_name = "github_repo_adapter/helper_create_issue_#{title_suffix.gsub(/\s+/, '_')}"

    VCR.use_cassette(cassette_name) do
      begin
        attributes = {
          title: title,
          description: "Test issue created by ActiveProject tests at #{timestamp}"
        }

        issue = @adapter.create_issue(@repo, attributes)
        puts "    Created test issue via helper: #{issue.key} - #{issue.title}"
      rescue StandardError => e
        puts "[ERROR] Failed to create test issue via helper: #{e.class} - #{e.message}"
      end
    end

    issue
  end
end
