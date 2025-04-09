# frozen_string_literal: true

require "test_helper"

# Base class for Jira Adapter tests, handling common setup and teardown.
class JiraAdapterBaseTest < ActiveSupport::TestCase
  TEST_JIRA_PROJECT_KEY = "LAC"
  TEST_JIRA_ISSUE_KEY = "LAC-10"
  # Define fixed names for deterministic VCR recording
  FIXED_TEST_PROJECT_KEY = "SKYNET"
  FIXED_TEST_PROJECT_NAME = "MELON MASK MARS PYRAMID SCHEME"
  FIXED_TEST_ISSUE_SUMMARY = "Base Setup Test Issue" # Can be used by tests if needed

  def setup
    @site_url = ENV.fetch("JIRA_SITE_URL", "https://clickup-core-team.atlassian.net")
    @username = ENV.fetch("JIRA_USERNAME", "DUMMY_JIRA_USERNAME")
    @api_token = ENV.fetch("JIRA_API_TOKEN", "DUMMY_JIRA_API_TOKEN")

    if VCR.current_cassette&.recording? && (@site_url.include?("core") || @username.include?("DUMMY") || @api_token.include?("DUMMY"))
      skip("Set JIRA_SITE_URL, JIRA_USERNAME, and JIRA_API_TOKEN environment variables to record VCR cassettes.")
    end

    @original_jira_config_options = ActiveProject.configuration.adapter_config(:jira)&.options&.dup || {}
    ActiveProject.configure do |config|
      config.add_adapter :jira, site_url: @site_url, username: @username, api_token: @api_token
    end
    @adapter = ActiveProject.adapter(:jira)

    # --- Project/Issue Creation REMOVED from base setup ---
    @live_test_project_key = nil
    @live_test_project_id = nil
    @live_test_issue_key = nil

    ActiveProject.reset_adapters # Clear memoization
  end

  def teardown
    ActiveProject.configure do |config|
      if @original_jira_config_options.any?
        config.add_adapter :jira, @original_jira_config_options
      else
        config.add_adapter :jira, {}
      end
    end
    # --- Project Deletion REMOVED from base teardown ---
    ActiveProject.reset_adapters
  end

  # Helper to create a live test project - Tests needing this should call it
  def create_live_test_project(key_suffix = "")
    lead_account_id = ENV["JIRA_TEST_LEAD_ACCOUNT_ID"] || "5e9360a3088a7e0c0f4c55f3"
    project_type_key = ENV.fetch("JIRA_TEST_PROJECT_TYPE_KEY", "software")

    timestamp_part = "123456789"
    # Calculate max length for the random suffix part
    max_suffix_len = 10 - "APTEST".length - key_suffix.length

    max_suffix_len = [ max_suffix_len, 1 ].max # Need at least 1 random char
    suffix = timestamp_part[-(max_suffix_len)..].rjust(max_suffix_len, "0")
    # Construct the key ensuring suffix is uppercase
    project_key = "APTEST#{key_suffix.upcase}#{suffix}"
    # Truncate if somehow still over 10 chars (shouldn't happen with calculation above)
    project_key = project_key[0...10]

    project_name = "AP Test #{project_key}"
    project = nil

    cassette_name = "jira_adapter/helper_create_project_#{project_key}"
    puts "\nAttempting to create test project '#{project_key}'..."
    VCR.use_cassette(cassette_name, record: :new_episodes) do
        begin
          attributes = {
            key: project_key,
            name: project_name,
            project_type_key: project_type_key,
            lead_account_id: lead_account_id,
            description: "Temp project for test #{project_key}",
            assignee_type: "PROJECT_LEAD"
          }
          project = @adapter.create_project(attributes)
          puts "    Created live test project via helper: Key=#{project.key}, ID=#{project.id}"
        rescue ActiveProject::ValidationError => e
          # Handle case where VCR replays an "already exists" error
          if e.message.include?("already exists") || e.message.include?("uses this project key")
             puts "    Project #{project_key} likely already exists (VCR replay). Attempting find..."
             begin
               project = @adapter.find_project(project_key) # Find it to return the object
               puts "    Found existing project #{project_key}."
             rescue => find_e
               puts "[ERROR] Failed to find existing project #{project_key} after creation conflict: #{find_e.message}"
               project = nil
             end
          else
            puts "[ERROR] Failed to create live test project via helper: #{e.class} - #{e.message}"
            project = nil
          end
        rescue => e
          puts "[ERROR] Failed to create live test project via helper: #{e.class} - #{e.message}"
          project = nil
        end
      end
    project # Return the created project object (or nil if failed)
  end

  # Helper to create a live test issue within a given project
  def create_live_test_issue(project, summary_suffix = "")
    refute_nil project, "Project object must be provided to create_live_test_issue"
    refute_nil project.id, "Project object must have an ID to create_live_test_issue"
    issue = nil
    # Use a more specific cassette name for helper-created issues
    # Keep :new_episodes as different tests might create different helper issues
    cassette_name = "jira_adapter/helper_create_issue_#{project.key}_#{summary_suffix.gsub(/\s+/, '_')}"
    VCR.use_cassette(cassette_name, record: :new_episodes) do
      issue_type_name = ENV.fetch("JIRA_TEST_ISSUE_TYPE_NAME", "Task")
      priority_name = ENV.fetch("JIRA_TEST_PRIORITY_NAME", "Medium")
      due_date = Date.today + 7
      attributes = {
        project: { id: project.id.to_s }, # Use project ID instead of key
        summary: "Live Test Issue #{summary_suffix} 1700000000", # Keep time here for uniqueness within helper calls
        description: "Issue created for testing #{summary_suffix}.",
        issue_type: { name: issue_type_name },
        due_on: due_date,
        priority: { name: priority_name }
      }
      begin
        # Check if issue already exists before creating (optional, adds complexity)
        puts "    Adding 2s delay before creating issue..."
        sleep 2
        issue = @adapter.create_issue(project.id, attributes) # Pass project ID (ignored anyway)
        puts "    Created live test issue via helper: #{issue.key}"
      rescue => e
        puts "[ERROR] Failed to create live test issue via helper: #{e.class} - #{e.message}"
      end
    end
    issue
  end

  # Helper to delete a project - Tests needing cleanup should call this
  def delete_live_test_project(project_key)
    return unless project_key
    puts "\nAttempting to delete test project '#{project_key}'..."
    cassette_name = "jira_adapter/helper_delete_project_#{project_key}"
    VCR.use_cassette(cassette_name, record: :new_episodes) do
      begin
        deleted = @adapter.delete_project(project_key)
        puts "    Deletion request for project #{project_key} successful." if deleted
      rescue ActiveProject::AuthenticationError => e
        puts "[WARN] Permission error deleting test project #{project_key}: #{e.message}."
      rescue ActiveProject::NotFoundError
        puts "    Test project #{project_key} already deleted or not found."
      rescue => e
        puts "[WARN] Unexpected error deleting test project #{project_key}: #{e.class} - #{e.message}."
      end
    end
  end
end
