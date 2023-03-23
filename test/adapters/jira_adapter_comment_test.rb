# frozen_string_literal: true

require_relative "jira_adapter_base_test"

# Tests for Jira Adapter Comment operations using static data.
class JiraAdapterCommentTest < JiraAdapterBaseTest
  test "#add_comment adds a comment to an existing issue" do
    issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use constant

    VCR.use_cassette("jira_adapter/add_comment_static") do # Use new cassette name
      comment_body = "Test comment added via ActiveProject static test at 1700000000"
      comment = @adapter.add_comment(issue_key_for_test, comment_body)

      assert_instance_of ActiveProject::Resources::Comment, comment
      assert_equal :jira, comment.adapter_source
      assert comment.id
      # Jira comment body might be in ADF format, check raw_data if exact match needed
      # For now, check if the input string is included
      assert comment.body.include?(comment_body.split(" at ").first), "Comment body does not match" # Check beginning part
      assert comment.author
      assert_instance_of ActiveProject::Resources::User, comment.author
      assert comment.created_at
      assert_equal issue_key_for_test, comment.issue_id
    end
  end
end
