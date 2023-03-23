# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"
class BasecampAdapterCommentTest < BasecampAdapterBaseTest
  test "add_comment adds a comment to a todo" do
    skip_if_missing_credentials_or_ids(needs_project: true, needs_todo: true)

    VCR.use_cassette("basecamp_adapter/add_comment_success") do
      comment_body = "Test comment from VCR test at 1700000000"
      # Remember to pass project_id in the options hash
      comment = @adapter.add_comment(@todo_id, comment_body, project_id: @project_id)

      assert_instance_of ActiveProject::Resources::Comment, comment
      assert_equal :basecamp, comment.adapter_source
      assert comment.id
      assert_equal comment_body, comment.body
      assert_equal @todo_id.to_i, comment.issue_id # Check if issue_id is mapped correctly
      assert comment.author
      assert_instance_of ActiveProject::Resources::User, comment.author
      assert comment.author.id
      assert comment.created_at
      assert_kind_of Time, comment.created_at
    end
  end
end
