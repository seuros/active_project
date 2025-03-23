# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterIssueListingTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Issue Listing Tests ---

  test "#list_issues returns array of Issue structs (Trello Cards) with default filter (open)" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_LIST_ISSUES")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for list_issues.")
    end

    VCR.use_cassette("trello_adapter/list_issues_open") do
      issues = @adapter.list_issues(board_id_for_test) # Default filter is 'open'
      assert_instance_of Array, issues
      unless issues.empty?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert_equal :trello, issues.first.adapter_source
        assert_equal board_id_for_test, issues.first.project_id
        assert_equal :open, issues.first.status # Default mapping before config
        assert_kind_of Array, issues.first.assignees
        unless issues.first.assignees.empty?
          assert_instance_of ActiveProject::Resources::User, issues.first.assignees.first
          assert issues.first.assignees.first.id # Check ID is present
        end
        assert_nil issues.first.reporter # Trello doesn't have a reporter
        assert issues.first.respond_to?(:due_on)
        assert_kind_of Date, issues.first.due_on if issues.first.due_on # Check type if present
        assert_nil issues.first.priority # Trello doesn't have priority

      end
    end
  end

  test "#list_issues returns array of Issue structs (Trello Cards) with filter 'closed'" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_LIST_ISSUES_CLOSED")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for list_issues (closed).")
    end

    VCR.use_cassette("trello_adapter/list_issues_closed") do
      issues = @adapter.list_issues(board_id_for_test, filter: "closed")
      assert_instance_of Array, issues
      unless issues.empty?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert_equal :trello, issues.first.adapter_source
        assert_equal board_id_for_test, issues.first.project_id
        assert_equal :closed, issues.first.status # Based on 'closed' field
        assert issues.first.respond_to?(:due_on)
        assert_kind_of Date, issues.first.due_on if issues.first.due_on # Check type if present

        assert_kind_of Array, issues.first.assignees
        unless issues.first.assignees.empty?
          assert_instance_of ActiveProject::Resources::User, issues.first.assignees.first
          assert issues.first.assignees.first.id
        end
        assert_nil issues.first.reporter # Trello doesn't have a reporter
        assert_nil issues.first.priority # Trello doesn't have priority
      end
    end
  end

  test "#list_issues returns array of Issue structs (Trello Cards) with filter 'all'" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_LIST_ISSUES_ALL")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for list_issues (all).")
    end

    VCR.use_cassette("trello_adapter/list_issues_all") do
      issues = @adapter.list_issues(board_id_for_test, filter: "all")
      assert_instance_of Array, issues
      unless issues.empty?
        assert_instance_of ActiveProject::Resources::Issue, issues.first
        assert_equal :trello, issues.first.adapter_source
        assert_equal board_id_for_test, issues.first.project_id
        assert issues.first.respond_to?(:due_on)
        assert_kind_of Date, issues.first.due_on if issues.first.due_on # Check type if present

        assert_includes [ :open, :closed ], issues.first.status # Before config mapping
        assert_kind_of Array, issues.first.assignees
        unless issues.first.assignees.empty?
          assert_instance_of ActiveProject::Resources::User, issues.first.assignees.first
          assert issues.first.assignees.first.id
        end
        assert_nil issues.first.reporter # Trello doesn't have a reporter
        assert_nil issues.first.priority # Trello doesn't have priority
      end
    end
  end
end
