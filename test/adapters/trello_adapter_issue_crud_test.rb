# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterIssueCrudTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Issue CRUD Tests ---

  test "#find_issue returns an Issue struct for a valid card ID" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID", "YOUR_CARD_ID_FOR_FIND_ISSUE")
    if card_id_for_test.include?("YOUR_CARD_ID")
      skip("Set TRELLO_TEST_CARD_ID environment variable to record VCR cassette for find_issue.")
    end

    VCR.use_cassette("trello_adapter/find_issue") do
      issue = @adapter.find_issue(card_id_for_test)
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal :trello, issue.adapter_source
      assert_equal card_id_for_test, issue.id
      assert issue.title
      assert issue.project_id
      assert issue.respond_to?(:due_on)
      assert_kind_of Date, issue.due_on if issue.due_on # Check type if present

      assert_includes [ :open, :closed ], issue.status
      assert_kind_of Array, issue.assignees
      unless issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, issue.assignees.first
        assert issue.assignees.first.id
      end
      assert_nil issue.reporter # Trello doesn't have a reporter
      assert_nil issue.priority # Trello doesn't have priority
    end
  end

  test "#create_issue creates a new card" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_CREATE_ISSUE")
    list_id_for_test = ENV.fetch("TRELLO_TEST_LIST_ID", "YOUR_LIST_ID_FOR_CREATE_ISSUE")
    if board_id_for_test.include?("YOUR_BOARD_ID") || list_id_for_test.include?("YOUR_LIST_ID")
      skip("Set TRELLO_TEST_BOARD_ID and TRELLO_TEST_LIST_ID environment variables to record VCR cassette for create_issue.")
    end

    VCR.use_cassette("trello_adapter/create_issue") do
      due_date = Date.today + 3
      attributes = {
        list_id: list_id_for_test,
        title: "Test Card from ActiveProject 1700000000",
        description: "Test description.",
        due_on: due_date
      }
      issue = @adapter.create_issue(board_id_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert issue.respond_to?(:due_on)
      assert_equal due_date, issue.due_on # Verify due date

      assert_equal attributes[:title], issue.title
      assert_equal :trello, issue.adapter_source
      assert_equal :open, issue.status
      assert_kind_of Array, issue.assignees
      # Check assignee type if present in VCR data (likely empty for new card unless specified)
      unless issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, issue.assignees.first
      end
      assert_nil issue.reporter # Trello doesn't have a reporter
      assert_nil issue.priority # Trello doesn't have priority
    end
  end

  test "#update_issue updates title and description for a valid card ID" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID", "YOUR_CARD_ID_FOR_UPDATE_ISSUE")
    if card_id_for_test.include?("YOUR_CARD_ID")
      skip("Set TRELLO_TEST_CARD_ID environment variable to record VCR cassette for update_issue.")
    end

    VCR.use_cassette("trello_adapter/update_issue_title_desc") do
      new_title = "Updated Title 1700000000"
      new_description = "Updated description at 1700000000."
      new_due_date = Date.today + 5
      attributes = { title: new_title, description: new_description, due_on: new_due_date }
      updated_issue = @adapter.update_issue(card_id_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal card_id_for_test, updated_issue.id
      assert_equal new_title, updated_issue.title
      assert_equal new_description, updated_issue.description
      assert_equal :trello, updated_issue.adapter_source
      assert_kind_of Array, updated_issue.assignees
      unless updated_issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, updated_issue.assignees.first
        assert updated_issue.assignees.first.id
      end
      assert_nil updated_issue.reporter # Trello doesn't have a reporter
      assert updated_issue.respond_to?(:due_on)
      assert_equal new_due_date, updated_issue.due_on # Verify updated due date
      assert_nil updated_issue.priority # Trello doesn't have priority
    end
  end

  test "#update_issue moves card to a different list" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID", "YOUR_CARD_ID_FOR_MOVE_ISSUE")
    target_list_id = ENV.fetch("TRELLO_TEST_TARGET_LIST_ID", "YOUR_TARGET_LIST_ID_FOR_MOVE")
    if card_id_for_test.include?("YOUR_CARD_ID") || target_list_id.include?("YOUR_TARGET_LIST_ID")
      skip("Set TRELLO_TEST_CARD_ID and TRELLO_TEST_TARGET_LIST_ID environment variables to record VCR cassette for update_issue (move list).")
    end

    VCR.use_cassette("trello_adapter/update_issue_move_list") do
      attributes = { list_id: target_list_id }
      updated_issue = @adapter.update_issue(card_id_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal card_id_for_test, updated_issue.id
      assert_equal target_list_id, updated_issue.raw_data["idList"] # Check raw data
      assert updated_issue.respond_to?(:due_on)
      assert_kind_of Date, updated_issue.due_on if updated_issue.due_on # Check type if present

      assert_equal :trello, updated_issue.adapter_source
      assert_kind_of Array, updated_issue.assignees
      unless updated_issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, updated_issue.assignees.first
        assert updated_issue.assignees.first.id
      end
      assert_nil updated_issue.reporter # Trello doesn't have a reporter
      assert_nil updated_issue.priority # Trello doesn't have priority
    end
  end

  test "#update_issue archives a card" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID", "YOUR_CARD_ID_FOR_ARCHIVE_ISSUE")
    if card_id_for_test.include?("YOUR_CARD_ID")
      skip("Set TRELLO_TEST_CARD_ID environment variable to record VCR cassette for update_issue (archive).")
    end

    VCR.use_cassette("trello_adapter/update_issue_archive") do
      attributes = { closed: true }
      updated_issue = @adapter.update_issue(card_id_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert updated_issue.respond_to?(:due_on)
      assert_kind_of Date, updated_issue.due_on if updated_issue.due_on # Check type if present

      assert_equal card_id_for_test, updated_issue.id
      assert_equal :closed, updated_issue.status
      assert_equal :trello, updated_issue.adapter_source
      assert_kind_of Array, updated_issue.assignees
      unless updated_issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, updated_issue.assignees.first
        assert updated_issue.assignees.first.id
      end
      assert_nil updated_issue.reporter # Trello doesn't have a reporter
      assert_nil updated_issue.priority # Trello doesn't have priority
    end
  end
   test "#update_issue unarchives a card" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID_ARCHIVED", "YOUR_ARCHIVED_CARD_ID_FOR_UNARCHIVE")
    if card_id_for_test.include?("YOUR_ARCHIVED_CARD_ID")
      skip("Set TRELLO_TEST_CARD_ID_ARCHIVED environment variable to record VCR cassette for update_issue (unarchive).")
    end

    VCR.use_cassette("trello_adapter/update_issue_unarchive") do
      attributes = { closed: false }
      updated_issue = @adapter.update_issue(card_id_for_test, attributes)
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert updated_issue.respond_to?(:due_on)
      assert_kind_of Date, updated_issue.due_on if updated_issue.due_on # Check type if present
      assert_equal card_id_for_test, updated_issue.id
      assert_equal :open, updated_issue.status # Should be open after unarchiving
      assert_equal :trello, updated_issue.adapter_source
      assert_kind_of Array, updated_issue.assignees
      unless updated_issue.assignees.empty?
        assert_instance_of ActiveProject::Resources::User, updated_issue.assignees.first
        assert updated_issue.assignees.first.id
      end
      assert_nil updated_issue.reporter # Trello doesn't have a reporter
      assert_nil updated_issue.priority # Trello doesn't have priority
    end
  end
end
