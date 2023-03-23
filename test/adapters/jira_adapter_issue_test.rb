# frozen_string_literal: true

require_relative "jira_adapter_base_test"

# Tests for Jira Adapter Issue operations using static data.
class JiraAdapterIssueTest < JiraAdapterBaseTest
  test "#list_issues returns array of Issue structs for a project" do
    project_key_for_test = TEST_JIRA_PROJECT_KEY # Use constant

    VCR.use_cassette("jira_adapter/list_issues_static") do
      issues = @adapter.list_issues(project_key_for_test)

      assert_instance_of Array, issues
      # Cannot guarantee non-empty without knowing the state of LAC project
      # refute_empty issues, "Expected to find at least one issue in project #{project_key_for_test}"
      if issues.any?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert_equal :jira, issues.first.adapter_source
        assert issues.first.id
        assert issues.first.key.start_with?(project_key_for_test), "Issue key should belong to project"
        assert issues.first.title
        assert_equal 10004, issues.first.project_id # Check against known project ID for LAC
        assert_includes [ :open, :in_progress, :closed, :unknown ], issues.first.status
      else
      end
    end
  end

  test "#find_issue returns an Issue struct for existing issue" do
    issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use constant

    VCR.use_cassette("jira_adapter/find_issue_success_static") do # New cassette name
      issue = @adapter.find_issue(issue_key_for_test)
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal issue_key_for_test, issue.key # Check key
      assert_equal :jira, issue.adapter_source
      assert issue.id # Check ID exists
      assert issue.title # Check title exists
      assert_equal 10004, issue.project_id # Check against known project ID for LAC
    end
  end

  test "#find_issue raises NotFoundError for non-existent issue" do
    VCR.use_cassette("jira_adapter/find_issue_not_found_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError) do
        # Use a key from a potentially non-existent project too
        @adapter.find_issue("NONEXISTENT-12345")
      end
    end
  end

  test "#create_issue creates a new issue in Jira" do
    # This test still needs dynamic creation, but we can use the static project key
    project_key_for_test = TEST_JIRA_PROJECT_KEY # Use constant
    created_issue = nil
    issue_key_to_delete = nil

    VCR.use_cassette("jira_adapter/create_issue_static_project") do # New cassette name
      attributes = {
        project: { key: project_key_for_test },
        summary: "Test Issue Static 1700000000",
        description: "Issue created for static project test.",
        issue_type: { name: "Bug" } # Changed from Task
        # Add other fields like priority, due_on if needed/desired
      }
      created_issue = @adapter.create_issue(project_key_for_test, attributes)
      issue_key_to_delete = created_issue.key # Store key for potential cleanup

      assert_instance_of ActiveProject::Resources::Issue, created_issue
      assert_equal project_key_for_test, created_issue.key.split("-").first
      assert created_issue.title.start_with?("Test Issue Static")
    end
  ensure
    # Attempt to delete the created issue (best effort cleanup)
    if issue_key_to_delete && @adapter
      VCR.use_cassette("jira_adapter/delete_created_issue_static_project_#{issue_key_to_delete}") do
        # Note: Jira API typically doesn't have a direct issue delete,
        # this might require specific permissions or workflows not covered here.
        # Placeholder for potential future cleanup logic if needed.
      end
    end
  end


  test "#update_issue updates an issue with static values" do
  issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use your constant here

  VCR.use_cassette("jira_adapter/update_issue_static") do
    # Static values that match exactly what's in the VCR cassette
    static_attributes = {
      summary: "Updated Summary Static 1700000000",
        description: "Updated description static test at 1700000000.",
        priority: { name: "High" }
      }

      updated_issue = @adapter.update_issue(issue_key_for_test, static_attributes)

      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal issue_key_for_test, updated_issue.key
      assert_equal "Updated Summary Static 1700000000", updated_issue.title
      assert updated_issue.description.include?("Updated description static test at 1700000000.")

      # Optional assertions (remove if not applicable)
      if updated_issue.respond_to?(:priority)
        assert_equal "High", updated_issue.priority
      end
    end
  end

  test "#create_issue raises ValidationError with invalid data (e.g., invalid issue type)" do
    project_key = TEST_JIRA_PROJECT_KEY # Use constant
    invalid_issue_type_name = "NonExistentIssueType123"

    VCR.use_cassette("jira_adapter/create_issue_validation_error_static") do # New cassette name
      attributes = {
        project: { key: project_key },
        summary: "Test Issue with Invalid Type Static 1700000000",
        description: "This should fail validation.",
        issue_type: { name: invalid_issue_type_name }
      }
      assert_raises(ActiveProject::ValidationError) do
        @adapter.create_issue(project_key, attributes)
      end
    end
  end
end
