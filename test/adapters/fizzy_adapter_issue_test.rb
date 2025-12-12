# frozen_string_literal: true

require_relative "fizzy_adapter_base_test"

class FizzyAdapterIssueTest < FizzyAdapterBaseTest
  # --- list_issues ---
  test "list_issues returns an array of issues for a board" do
    VCR.use_cassette("fizzy/list_issues") do
      issues = @adapter.list_issues(@board_id)
      assert_kind_of Array, issues
      assert issues.any?, "Expected at least one issue (card)"
      first_issue = issues.first
      assert_kind_of ActiveProject::Resources::Issue, first_issue
      assert_not_nil first_issue.id
      assert_not_nil first_issue.key # Card number
      assert_not_nil first_issue.title
      assert_equal :fizzy, first_issue.adapter_source
    end
  end

  # --- find_issue ---
  test "find_issue returns an issue by card number" do
    VCR.use_cassette("fizzy/find_issue") do
      issue = @adapter.find_issue(@card_number)
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_equal @card_number.to_s, issue.key
      assert_not_nil issue.title
      assert_equal :fizzy, issue.adapter_source
    end
  end

  test "find_issue raises NotFoundError for invalid card number" do
    VCR.use_cassette("fizzy/find_issue_not_found") do
      assert_raises ActiveProject::NotFoundError do
        @adapter.find_issue(999999)
      end
    end
  end

  # --- create_issue ---
  test "create_issue creates a new card" do
    VCR.use_cassette("fizzy/create_issue") do
      issue = @adapter.create_issue(@board_id, title: "Test Card #{TIMESTAMP_PLACEHOLDER}")
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_not_nil issue.id
      assert_not_nil issue.key
      assert issue.title.start_with?("Test Card")
      assert_equal :fizzy, issue.adapter_source
    end
  end

  test "create_issue with description" do
    VCR.use_cassette("fizzy/create_issue_with_description") do
      issue = @adapter.create_issue(@board_id,
                                    title: "Card with Description",
                                    description: "<p>This is a <strong>rich text</strong> description.</p>")
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_equal "Card with Description", issue.title
    end
  end

  test "create_issue raises ArgumentError without title" do
    assert_raises ArgumentError do
      @adapter.create_issue(@board_id, {})
    end
  end

  # --- update_issue ---
  test "update_issue updates card title" do
    VCR.use_cassette("fizzy/update_issue_title") do
      updated_title = "Updated Title #{TIMESTAMP_PLACEHOLDER}"
      issue = @adapter.update_issue(@card_number, { title: updated_title })
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_equal updated_title, issue.title
    end
  end

  test "update_issue closes card" do
    VCR.use_cassette("fizzy/update_issue_close") do
      issue = @adapter.update_issue(@card_number, { status: :closed })
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_equal :closed, issue.status
    end
  end

  test "update_issue reopens card" do
    VCR.use_cassette("fizzy/update_issue_reopen") do
      issue = @adapter.update_issue(@card_number, { status: :open })
      assert_kind_of ActiveProject::Resources::Issue, issue
      assert_equal :open, issue.status
    end
  end

  test "update_issue raises ArgumentError without attributes" do
    assert_raises ArgumentError do
      @adapter.update_issue(@card_number, {})
    end
  end

  # --- delete_issue ---
  test "delete_issue deletes a card" do
    VCR.use_cassette("fizzy/delete_issue") do
      # First create a card to delete
      issue = @adapter.create_issue(@board_id, title: "Card to Delete #{TIMESTAMP_PLACEHOLDER}")
      card_number = issue.key

      # Then delete it
      result = @adapter.delete_issue(card_number)
      assert_equal true, result
    end
  end
end
