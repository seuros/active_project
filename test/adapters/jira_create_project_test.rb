# frozen_string_literal: true

require "test_helper"

# Separate tests for Jira project creation
class JiraCreateProjectTest < ActiveSupport::TestCase
  def setup
    @site_url = ENV.fetch("JIRA_SITE_URL", "https://clickup-core-team.atlassian.net")
    @username = ENV.fetch("JIRA_USERNAME", "DUMMY_JIRA_USERNAME")
    @api_token = ENV.fetch("JIRA_API_TOKEN", "DUMMY_JIRA_API_TOKEN")
    @lead_account_id = ENV.fetch("JIRA_TEST_LEAD_ACCOUNT_ID", "DUMMY_LEAD_ID") # Required for creation

    # Store original config options for restoration
    @original_jira_config_options = ActiveProject.configuration.adapter_config(:jira)&.options&.dup || {}


    ActiveProject.configure do |config|
      config.add_adapter :jira, site_url: @site_url, username: @username, api_token: @api_token
    end

    # Initialize adapter using the new config structure via the helper
    @adapter = ActiveProject.adapter(:jira)
    # Clear memoized adapter instance
    ActiveProject.instance_variable_set(:@adapters, {})
  end

  def teardown
    # Restore original config options after each test
    ActiveProject.configure do |config|
      if @original_jira_config_options.any?
        config.add_adapter :jira, @original_jira_config_options
      else
        config.add_adapter :jira, {} # Reset if no original
      end
    end
    # Clear memoized adapter instance again after teardown
    ActiveProject.instance_variable_set(:@adapters, {})
  end

  def skip_if_missing_credentials
    if @site_url.include?("dummy") || @username.include?("DUMMY") || @api_token.include?("DUMMY") || @lead_account_id.include?("DUMMY")
      skip("Set JIRA_SITE_URL, JIRA_USERNAME, JIRA_API_TOKEN, and JIRA_TEST_LEAD_ACCOUNT_ID environment variables to record VCR cassettes.")
    end
  end

  test "#create_project creates a new project" do
    skip_if_missing_credentials

    VCR.use_cassette("jira_adapter/create_project") do
      timestamp = 1700000000
      attributes = {
        key: "CP#{timestamp.to_s[-4..]}", # Generate a somewhat unique key
        name: "Test Project #{timestamp}",
        project_type_key: "software", # Common type
        lead_account_id: @lead_account_id,
        description: "Test project created by ActiveProject gem."
      }

      project = @adapter.create_project(attributes)

      assert_instance_of ActiveProject::Resources::Project, project # Check resource type
      assert_equal :jira, project.adapter_source
      assert project.id
      assert_equal attributes[:key], project.key
      assert_equal attributes[:name], project.name
      # Note: Deleting the created project might be necessary for test cleanup in a real scenario
    end
  end

  test "#create_project raises ArgumentError if required fields are missing" do
    assert_raises(ArgumentError, /Missing required attributes.*:key/) do
      @adapter.create_project(name: "No Key", project_type_key: "software", lead_account_id: "id")
    end
    assert_raises(ArgumentError, /Missing required attributes.*:name/) do
      @adapter.create_project(key: "NK", project_type_key: "software", lead_account_id: "id")
    end
    assert_raises(ArgumentError, /Missing required attributes.*:project_type_key/) do
      @adapter.create_project(key: "NK", name: "No Type", lead_account_id: "id")
    end
     assert_raises(ArgumentError, /Missing required attributes.*:lead_account_id/) do
      @adapter.create_project(key: "NK", name: "No Lead", project_type_key: "software")
    end
  end
end
