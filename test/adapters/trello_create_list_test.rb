# frozen_string_literal: true

require "test_helper"

# Separate tests for Trello list creation
class TrelloCreateListTest < ActiveSupport::TestCase
  def setup
    @api_key = ENV.fetch("TRELLO_API_KEY", "DUMMY_TRELLO_KEY")
    @api_token = ENV.fetch("TRELLO_API_TOKEN", "DUMMY_TRELLO_TOKEN")
    @board_id = ENV.fetch("TRELLO_TEST_BOARD_ID", "DUMMY_BOARD_ID") # Need board ID

    # Store original config options for restoration
    @original_trello_config_options = ActiveProject.configuration.adapter_config(:trello)&.options&.dup || {}


    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: @api_key, api_token: @api_token do |trello_config|
        trello_config.status_mappings = {} # Default empty mappings
      end
    end

    # Initialize adapter using the new config structure via the helper
    @adapter = ActiveProject.adapter(:trello)
    # Clear memoized adapter instance
    ActiveProject.instance_variable_set(:@adapters, {})
  end

  def teardown
    # Restore original config options after each test
    ActiveProject.configure do |config|
      if @original_trello_config_options.any?
         original_mappings = @original_trello_config_options.delete(:status_mappings)
         if original_mappings
           config.add_adapter :trello, @original_trello_config_options do |trello_config|
             trello_config.status_mappings = original_mappings
           end
         else
           config.add_adapter :trello, @original_trello_config_options
         end
      else
         config.add_adapter :trello, {}
      end
    end
    # Clear memoized adapter instance again after teardown
    ActiveProject.instance_variable_set(:@adapters, {})
  end


  def skip_if_missing_credentials_or_ids
    if @api_key.include?("DUMMY") || @api_token.include?("DUMMY") || @board_id.include?("DUMMY")
      skip("Set TRELLO_API_KEY, TRELLO_API_TOKEN, and TRELLO_TEST_BOARD_ID environment variables.")
    end
  end

  test "#create_list creates a new list on a board" do
    skip_if_missing_credentials_or_ids

    VCR.use_cassette("trello_adapter/create_list") do
      timestamp = 1700000000
      attributes = {
        name: "Test List #{timestamp}"
        # Add :pos if needed, e.g., pos: 'bottom'
      }

      # create_list returns the raw hash from the API
      list_data = @adapter.create_list(@board_id, attributes)

      assert_instance_of Hash, list_data
      assert list_data["id"]
      assert_equal attributes[:name], list_data["name"]
      assert_equal @board_id, list_data["idBoard"]
      # Note: Deleting the created list might be necessary for test cleanup
      # Trello API allows archiving lists: PUT /lists/{id}/closed?value=true
    end
  end

  test "#create_list raises ArgumentError if name is missing" do
    assert_raises(ArgumentError, /Missing required attribute for Trello list creation: :name/) do
      @adapter.create_list(@board_id, {})
    end
  end

  test "#create_list raises NotFoundError if board is invalid" do
     skip_if_missing_credentials_or_ids # Need credentials to make the call
     invalid_board_id = "invalidBoardId123"
     VCR.use_cassette("trello_adapter/create_list_invalid_board") do
        assert_raises(ActiveProject::NotFoundError) do
          @adapter.create_list(invalid_board_id, { name: "Test List" })
        end
     end
  end
end
