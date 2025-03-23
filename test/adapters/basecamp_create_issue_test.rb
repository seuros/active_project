# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

class BasecampCreateIssueTest < BasecampAdapterBaseTest
  test "#create_issue creates a new todo" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todolist: true)

    VCR.use_cassette("basecamp_adapter/create_issue") do
      attributes = {
        todolist_id: @todolist_id,
        title: "Test ToDo from ActiveProject 1743945018", # Use static title for VCR
        description: "This is a test description.",
        assignee_ids: [] # Example: Pass assignee IDs if needed
      }
      issue = @adapter.create_issue(@project_id, attributes)

      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal attributes[:title], issue.title
      assert_equal :basecamp, issue.adapter_source
      assert_equal :open, issue.status # Should be open by default
      assert_kind_of Array, issue.assignees
      assert issue.respond_to?(:due_on)
      assert issue.respond_to?(:due_on)


      # Add assertion for assignee IDs if passed and expected in response mapping
    end
  end
end
