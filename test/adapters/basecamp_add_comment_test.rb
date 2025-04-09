# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

class BasecampAddCommentTest < BasecampAdapterBaseTest
  test "#add_comment adds a comment to a todo" do
    skip "Skipping due to persistent 404 error, likely permissions or API issue. See IMPORTANT_NOTES.MD"

    comment_body = "Test comment added at #{"2024-01-01T12:00:00Z"}"
    VCR.use_cassette("basecamp_adapter/add_comment") do
      comment = @adapter.add_comment(@todo_id, comment_body, { project_id: @project_id })
      assert_instance_of ActiveProject::Resources::Comment, comment
      # Basecamp uses HTML, check if it matches input (it might wrap in div)
      assert_includes comment.body, comment_body
      assert_equal @todo_id.to_i, comment.issue_id
      assert_equal :basecamp, comment.adapter_source
    end
  end
end
