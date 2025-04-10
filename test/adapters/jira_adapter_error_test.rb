# frozen_string_literal: true

require_relative "jira_adapter_base_test"

# Tests for Jira Adapter Error Handling scenarios.
class JiraAdapterErrorTest < JiraAdapterBaseTest
  # NOTE: Some error tests (like find_project not found, create_project validation)
  # are kept within their respective functional test files (project_test, issue_test)
  # for better context. This file focuses on broader error conditions.

  test "#find_issue raises NotFoundError for non-existent issue key (error handling section)" do
    VCR.use_cassette("jira_adapter/find_issue_not_found_error_section") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue("NONEXISTENT-999")
      end
    end
  end

  test "adapter raises AuthenticationError with invalid credentials" do
    # Configure with bad credentials specifically for this test
    ActiveProject.configure do |config|
      config.add_adapter :jira, site_url: @site_url, username: "invalid-user", api_token: "invalid-token"
    end
    bad_adapter = ActiveProject.adapter(:jira) # Get the adapter with bad config

    # Use a method that requires authentication, like list_projects
    VCR.use_cassette("jira_adapter/authentication_error") do
      assert_raises(ActiveProject::AuthenticationError) do
        bad_adapter.list_projects
      end
    end
    # Restore good config after this test (teardown in base class handles this)
  end

  # Example of keeping a specific validation error test here if desired,
  # although the create_issue validation for invalid type is in issue_test.
  # test "#create_issue raises ValidationError with invalid project key" do
  #   VCR.use_cassette("jira_adapter/create_issue_invalid_project_key") do
  #     attributes = {
  #       project: { key: "INVALIDPROJECTKEY" },
  #       summary: "Test Issue with Invalid Project #{Time.now.to_i}",
  #       issue_type: { name: ENV.fetch("JIRA_TEST_ISSUE_TYPE_NAME", "Task") }
  #     }
  #     assert_raises(ActiveProject::ValidationError) do # Or potentially NotFoundError depending on API
  #       @adapter.create_issue("INVALIDPROJECTKEY", attributes)
  #     end
  #   end
  # end
end
