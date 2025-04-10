# frozen_string_literal: true

require_relative "jira_adapter_base_test"

class JiraAdapterDeleteIssueTest < JiraAdapterBaseTest
  test "#delete_issue deletes an issue from Jira" do
    project_key_for_test = TEST_JIRA_PROJECT_KEY
    issue_key_to_delete = nil

    # First, create an issue to delete
    VCR.use_cassette("jira_adapter/create_issue_for_delete") do
      attributes = {
        project: { key: project_key_for_test },
        summary: "Issue to Delete 1700000000",
        description: "This issue will be deleted in the test.",
        issue_type: { name: "Bug" }
      }

      created_issue = @adapter.create_issue(project_key_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, created_issue
      issue_key_to_delete = created_issue.key
    end

    # Now delete the issue
    VCR.use_cassette("jira_adapter/delete_issue") do
      # Execute the deletion
      result = @adapter.delete_issue(issue_key_to_delete)

      # Check that deletion was successful
      assert result, "delete_issue should return true on success"

      # Verify issue is no longer accessible
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(issue_key_to_delete)
      end
    end
  end

  test "#delete_issue with delete_subtasks deletes issue and its subtasks" do
    project_key_for_test = TEST_JIRA_PROJECT_KEY
    parent_issue_key = nil
    subtask_issue_key = nil

    # First, create a parent issue
    VCR.use_cassette("jira_adapter/create_parent_issue_for_delete") do
      attributes = {
        project: { key: project_key_for_test },
        summary: "Parent Issue 1700000000",
        description: "This is a parent issue that will have subtasks.",
        issue_type: { name: "Bug" }
      }

      parent_issue = @adapter.create_issue(project_key_for_test, attributes)
      parent_issue_key = parent_issue.key
    end

    # Then create a subtask
    VCR.use_cassette("jira_adapter/create_subtask_for_delete") do
      attributes = {
        project: { key: project_key_for_test },
        summary: "Subtask Issue 1700000000",
        description: "This is a subtask that will be deleted with parent.",
        issue_type: { name: "Sub-task" },
        parent: { key: parent_issue_key }
      }

      subtask_issue = @adapter.create_issue(project_key_for_test, attributes)
      subtask_issue_key = subtask_issue.key
    end

    # Now delete the parent issue with subtasks
    VCR.use_cassette("jira_adapter/delete_issue_with_subtasks") do
      # Execute the deletion with delete_subtasks flag
      result = @adapter.delete_issue(parent_issue_key, delete_subtasks: true)

      # Check that deletion was successful
      assert result, "delete_issue should return true on success"

      # Verify parent issue is no longer accessible
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(parent_issue_key)
      end

      # Verify subtask is no longer accessible
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(subtask_issue_key)
      end
    end
  end

  test "#delete_issue raises NotFoundError for non-existent issue" do
    non_existent_issue_key = "NONEXISTENT-12345"

    VCR.use_cassette("jira_adapter/delete_issue_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_issue(non_existent_issue_key)
      end
    end
  end
end
