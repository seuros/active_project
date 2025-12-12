# frozen_string_literal: true

require_relative "fizzy_adapter_base_test"

class FizzyAdapterCommentTest < FizzyAdapterBaseTest
  # --- list_comments ---
  test "list_comments returns an array of comments" do
    VCR.use_cassette("fizzy/list_comments") do
      comments = @adapter.list_comments(@card_number)
      assert_kind_of Array, comments
      # May or may not have comments depending on test data
    end
  end

  # --- add_comment ---
  test "add_comment creates a new comment on a card" do
    VCR.use_cassette("fizzy/add_comment") do
      comment = @adapter.add_comment(@card_number, "Test comment #{TIMESTAMP_PLACEHOLDER}")
      assert_kind_of ActiveProject::Resources::Comment, comment
      assert_not_nil comment.id
      assert comment.body.include?("Test comment")
      assert_equal :fizzy, comment.adapter_source
    end
  end

  test "add_comment with rich text" do
    VCR.use_cassette("fizzy/add_comment_rich_text") do
      comment = @adapter.add_comment(@card_number, "<p>This is <strong>bold</strong> text.</p>")
      assert_kind_of ActiveProject::Resources::Comment, comment
      assert_not_nil comment.id
    end
  end

  # --- find_comment ---
  test "find_comment returns a specific comment" do
    VCR.use_cassette("fizzy/find_comment") do
      # First create a comment
      created = @adapter.add_comment(@card_number, "Comment to find #{TIMESTAMP_PLACEHOLDER}")
      comment_id = created.id

      # Then find it
      comment = @adapter.find_comment(@card_number, comment_id)
      assert_kind_of ActiveProject::Resources::Comment, comment
      assert_equal comment_id, comment.id
    end
  end

  # --- update_comment ---
  test "update_comment updates a comment body" do
    VCR.use_cassette("fizzy/update_comment") do
      # First create a comment
      created = @adapter.add_comment(@card_number, "Original comment body")
      comment_id = created.id

      # Then update it
      updated_body = "Updated comment body #{TIMESTAMP_PLACEHOLDER}"
      comment = @adapter.update_comment(@card_number, comment_id, updated_body)
      assert_kind_of ActiveProject::Resources::Comment, comment
      assert comment.body.include?("Updated comment body")
    end
  end

  # --- delete_comment ---
  test "delete_comment deletes a comment" do
    VCR.use_cassette("fizzy/delete_comment") do
      # First create a comment
      created = @adapter.add_comment(@card_number, "Comment to delete #{TIMESTAMP_PLACEHOLDER}")
      comment_id = created.id

      # Then delete it
      result = @adapter.delete_comment(@card_number, comment_id)
      assert_equal true, result
    end
  end
end
