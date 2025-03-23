# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"
class BasecampAdapterIssueTest < BasecampAdapterBaseTest
  test "#find_issue returns an Issue struct for existing todo" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todo: true)

    VCR.use_cassette("basecamp_adapter/find_issue_success") do
      issue = @adapter.find_issue(@todo_id, { project_id: @project_id })
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal @todo_id, issue.id.to_s
      assert_equal @project_id, issue.project_id
      assert_equal :basecamp, issue.adapter_source
      assert_kind_of Array, issue.assignees
      unless issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, issue.assignees.first
        assert issue.assignees.first.id
      end
      assert issue.reporter # Check reporter exists
      assert_instance_of ActiveProject::Resources::User, issue.reporter
      assert issue.reporter.id
      assert issue.respond_to?(:due_on)
      assert_kind_of Date, issue.due_on if issue.due_on # Check type if present
      assert_nil issue.priority # Basecamp doesn't have priority
    end
  end

  test "#list_issues returns array of Issue structs (todos) for project's first todolist by default" do
    skip_if_missing_credentials_or_ids(needs_project: true)

    VCR.use_cassette("basecamp_adapter/list_issues_default_todolist") do
      issues = @adapter.list_issues(@project_id)
      assert_instance_of Array, issues
      unless issues.empty?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert_equal :basecamp, issues.first.adapter_source
        assert_equal @project_id.to_i, issues.first.project_id
        assert issues.first.respond_to?(:due_on)
        assert_kind_of Date, issues.first.due_on if issues.first.due_on # Check type if present

        assert_includes [ :open, :closed ], issues.first.status
        assert_kind_of Array, issues.first.assignees
        unless issues.first.assignees.empty?
          assert_instance_of ActiveProject::Resources::User, issues.first.assignees.first
          assert issues.first.assignees.first.id
        end
        assert issues.first.reporter # Check reporter exists
        assert_instance_of ActiveProject::Resources::User, issues.first.reporter
        assert issues.first.reporter.id
        assert_nil issues.first.priority # Basecamp doesn't have priority
      end
    end
  end

  test "#list_issues returns array of Issue structs for a specific todolist" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todolist: true)

    VCR.use_cassette("basecamp_adapter/list_issues_specific_todolist") do
      issues = @adapter.list_issues(@project_id, todolist_id: @todolist_id)
      assert_instance_of Array, issues
      unless issues.empty?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert issues.first.respond_to?(:due_on)
        assert_kind_of Date, issues.first.due_on if issues.first.due_on # Check type if present

        assert_equal :basecamp, issues.first.adapter_source
        assert_equal @project_id.to_s, issues.first.project_id
        assert_includes [ :open, :closed ], issues.first.status
        assert_kind_of Array, issues.first.assignees
        unless issues.first.assignees.empty?
          assert_instance_of ActiveProject::Resources::User, issues.first.assignees.first
          assert issues.first.assignees.first.id
        end
        # assert issues.first.reporter # Check reporter exists
        # assert_instance_of ActiveProject::Resources::User, issues.first.reporter
        # assert issues.first.reporter.id
        assert_nil issues.first.priority # Basecamp doesn't have priority
      end
    end
  end

  test "create_issue creates a new todo" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todolist: true)

    VCR.use_cassette("basecamp_adapter/create_issue_success") do
      issue_title = "Test To-do from VCR test at 1700000000"
      attributes = {
        todolist_id: @todolist_id,
        title: issue_title,
        description: "This is a test to-do created via the adapter.",
        due_on: Time.parse("Sat, 27 Mar 2025")
        # assignee_ids could be added here if needed for testing
      }

      issue = @adapter.create_issue(@project_id, attributes)

      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal :basecamp, issue.adapter_source
      assert issue.id
      assert_equal issue_title, issue.title
      assert_equal attributes[:description], issue.description
      assert_equal @project_id, issue.project_id
      assert_equal :open, issue.status # New todos are open
      assert_equal "2025-03-15", issue.due_on.to_s
      # assert issue.reporter # Creator should be mapped
      # assert_instance_of ActiveProject::Resources::User, issue.reporter
      assert issue.created_at
      assert_kind_of Time, issue.created_at
    end
  end


  test "update_issue updates a todo" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todolist: true)

    # Create an issue first to update
    issue_to_update = nil
    VCR.use_cassette("basecamp_adapter/update_issue_create_step") do
      issue_title = "To-do to be updated 1700000000"
      attributes = { todolist_id: @todolist_id, title: issue_title }
      issue_to_update = @adapter.create_issue(@project_id, attributes)
      assert issue_to_update, "Failed to create issue for update test"
      assert issue_to_update.id, "Created issue has no ID"
    end

    # Now update the issue
    updated_title = "Updated Title 1700000000"
    updated_description = "Updated description text."
    updated_status = :closed
    updated_due_on = Date.parse("2025-04-23")

    VCR.use_cassette("basecamp_adapter/update_issue_update_step") do
      update_attributes = {
        title: updated_title,
        description: updated_description,
        status: updated_status,
        due_on: updated_due_on
        # assignee_ids could be updated here too
      }
      # Remember context is needed for update_issue
      updated_issue = @adapter.update_issue(issue_to_update.id, update_attributes, project_id: @project_id)

      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal updated_title, updated_issue.title
      assert_equal updated_description, updated_issue.description

      assert_equal updated_due_on, updated_issue.due_on
    end

    # Optional: Verify by fetching again
    VCR.use_cassette("basecamp_adapter/update_issue_verify_step") do
      fetched_issue = @adapter.find_issue(issue_to_update.id, project_id: @project_id)
      assert_equal updated_title, fetched_issue.title
      assert_equal updated_description, fetched_issue.description
      assert_equal updated_status, fetched_issue.status
      # assert_equal updated_due_on, fetched_issue.due_on
    end
  end
end
