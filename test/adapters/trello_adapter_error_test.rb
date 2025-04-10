# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterErrorTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Error Handling Tests ---

  test "#find_issue raises NotFoundError for an invalid card ID" do
    invalid_card_id = "invalidCardIdThatDoesNotExist123"
    VCR.use_cassette("trello_adapter/find_issue_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(invalid_card_id)
      end
    end
  end

  test "adapter raises AuthenticationError with invalid credentials" do
    # Configure with bad credentials specifically for this test
    # This overrides the base setup for this specific test case
    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: "invalid-key", api_token: "invalid-token"
    end
    # Clear memoized adapter instance to pick up bad config
    ActiveProject.reset_adapters
    bad_adapter = ActiveProject.adapter(:trello) # Get the adapter with bad config

    VCR.use_cassette("trello_adapter/authentication_error") do
      assert_raises(ActiveProject::AuthenticationError) do
        bad_adapter.list_projects
      end
    end
    # Teardown will restore the original (good) credentials
  end

  test "#create_issue raises ValidationError with missing required attributes" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_VALIDATION_ERROR")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for create_issue (validation error).")
    end

    # Use VCR or WebMock stubbing for this if the API call is needed to trigger validation
    # For Trello, the ArgumentError happens before the API call if list_id is missing
    # VCR.use_cassette("trello_adapter/create_issue_validation_error") do
    attributes = { title: "Test Card with Missing List ID 1700000000" }
    # Trello adapter raises ArgumentError locally before API call if list_id is missing
    assert_raises(ArgumentError, /Missing required attributes for Trello card creation: :list_id, :title/) do
      @adapter.create_issue(board_id_for_test, attributes)
    end
    # end
  end
end
