# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterListTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- List Tests ---

  test "#create_list creates a new list on a Trello board" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_CREATE_LIST")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for create_list.")
    end
    skip_if_missing_credentials # Use helper from base class

    VCR.use_cassette("trello_adapter/create_list_success") do
      list_name = "Test List via ActiveProject 1700000000"
      attributes = {
        name: list_name,
        pos: "bottom" # Optional position
      }

      # Method returns the raw hash of the created list
      created_list_data = @adapter.create_list(board_id_for_test, attributes)

      assert_instance_of Hash, created_list_data
      assert created_list_data["id"]
      assert_equal list_name, created_list_data["name"]
      assert_equal board_id_for_test, created_list_data["idBoard"]

      # Cleanup: Trello API allows archiving lists.
      # Consider adding cleanup if necessary.
      # Example (requires implementing #delete_list or similar):
      # @adapter.delete_list(created_list_data["id"]) if created_list_data&.dig("id")
    end
  end

  test "#create_list raises ArgumentError with missing required attributes" do
    # No VCR needed
    board_id_for_test = "dummy_board_id" # Doesn't matter for this test
    attributes = {
      pos: "top"
      # Missing name
    }
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_list(board_id_for_test, attributes)
    end
  end

  test "#create_list raises NotFoundError for non-existent board ID" do
    skip_if_missing_credentials # Use helper from base class

    invalid_board_id = "invalidBoardIdThatDoesNotExist123"
    VCR.use_cassette("trello_adapter/create_list_board_not_found") do
      attributes = { name: "Test List for Invalid Board" }
      # The API call POST /boards/{invalid_board_id}/lists should fail
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.create_list(invalid_board_id, attributes)
      end
    end
  end
end
