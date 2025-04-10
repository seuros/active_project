# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

class BasecampAdapterDeleteIssueTest < BasecampAdapterBaseTest
  test "#delete_issue deletes a todo from Basecamp" do
    project_id = @project_id
    todolist_id = @todolist_id
    todo_id_for_test = nil

    # First, create a todo to delete
    VCR.use_cassette("basecamp_adapter/create_todo_for_delete") do
      attributes = {
        todolist_id: todolist_id,
        title: "Todo to Delete 1700000000",
        description: "This todo will be deleted in the test."
      }

      todo = @adapter.create_issue(project_id, attributes)
      assert_instance_of ActiveProject::Resources::Issue, todo
      todo_id_for_test = todo.id
    end

    # Now delete the todo
    VCR.use_cassette("basecamp_adapter/delete_issue") do
      # Execute the deletion
      result = @adapter.delete_issue(todo_id_for_test, project_id: project_id)

      # Check that deletion was successful
      assert result, "delete_issue should return true on success"

      # Verify todo is no longer accessible
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(todo_id_for_test, project_id: project_id)
      end
    end
  end

  test "#delete_issue requires project_id in context" do
    todo_id_for_test = "12345"

    assert_raises(ArgumentError) do
      @adapter.delete_issue(todo_id_for_test)
    end
  end

  test "#delete_issue raises NotFoundError for non-existent todo" do
    project_id = @project_id
    non_existent_todo_id = "9999999"

    VCR.use_cassette("basecamp_adapter/delete_issue_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_issue(non_existent_todo_id, project_id: project_id)
      end
    end
  end
end
