# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

class BasecampUpdateIssueTest < BasecampAdapterBaseTest
  test "#update_issue updates a todo title" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todo: true)

    new_title = "Updated Title 1700000000"
    VCR.use_cassette("basecamp_adapter/update_issue_title") do
      updated_issue = @adapter.update_issue(@todo_id, { title: new_title }, { project_id: @project_id })
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal new_title, updated_issue.title
      assert_kind_of Array, updated_issue.assignees
      assert updated_issue.respond_to?(:due_on)
      assert updated_issue.respond_to?(:due_on)
    end
  end

  # Add more tests for updating other fields like description, assignees, status, due_on
  # Example for status:
  # test "#update_issue updates status (completion)" do
  #   skip_if_missing_credentials_or_ids(needs_project: true, needs_todo: true)
  #
  #   VCR.use_cassette("basecamp_adapter/update_issue_status") do
  #     # Close it
  #     closed_issue = @adapter.update_issue(@todo_id, { status: :closed }, { project_id: @project_id })
  #     assert_equal :closed, closed_issue.status
  #
  #     # Reopen it
  #     reopened_issue = @adapter.update_issue(@todo_id, { status: :open }, { project_id: @project_id })
  #     assert_equal :open, reopened_issue.status
  #   end
  # end
end
