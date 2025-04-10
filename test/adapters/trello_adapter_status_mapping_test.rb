# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterStatusMappingTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Status Mapping Tests ---

  test "#map_card_data uses configured status mappings" do
    board_id = "BOARD_WITH_MAPPING"
    list_open_id = "LIST_OPEN"
    list_progress_id = "LIST_PROGRESS"
    list_closed_id = "LIST_CLOSED"

    # Configure status mappings specifically for this test
    # This overrides the base setup configuration for this test scope
    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: @api_key, api_token: @api_token do |trello_config|
        trello_config.status_mappings = {
          board_id => {
            list_open_id => :open,
            list_progress_id => :in_progress,
            list_closed_id => :closed
          }
        }
      end
    end
    # Re-initialize adapter to pick up new config for this test
    ActiveProject.reset_adapters # Clear memoized instance
    adapter_for_test = ActiveProject.adapter(:trello)

    card_data_open = { "id" => "card1", "name" => "Card 1", "idList" => list_open_id, "closed" => false,
                       "idBoard" => board_id, "idMembers" => [ "m1" ] }
    card_data_progress = { "id" => "card2", "name" => "Card 2", "idList" => list_progress_id, "closed" => false,
                           "idBoard" => board_id, "idMembers" => [] }
    card_data_closed_list = { "id" => "card3", "name" => "Card 3", "idList" => list_closed_id, "closed" => false,
                              "idBoard" => board_id, "idMembers" => %w[m1 m2] }
    card_data_archived = { "id" => "card4", "name" => "Card 4", "idList" => list_open_id, "closed" => true,
                           "idBoard" => board_id, "idMembers" => nil }
    card_data_unmapped = { "id" => "card5", "name" => "Card 5", "idList" => "UNMAPPED_LIST", "closed" => false,
                           "idBoard" => board_id, "idMembers" => [ "m3" ] }

    issue_open = adapter_for_test.send(:map_card_data, card_data_open, board_id)
    issue_progress = adapter_for_test.send(:map_card_data, card_data_progress, board_id)
    issue_closed_list = adapter_for_test.send(:map_card_data, card_data_closed_list, board_id)
    issue_archived = adapter_for_test.send(:map_card_data, card_data_archived, board_id)
    issue_unmapped = adapter_for_test.send(:map_card_data, card_data_unmapped, board_id)

    assert_equal :open, issue_open.status
    assert_equal :in_progress, issue_progress.status
    assert_equal :closed, issue_closed_list.status
    assert_equal :closed, issue_archived.status # Archived takes precedence
    assert_equal :open, issue_unmapped.status # Defaults to open if unmapped and not archived
    assert_kind_of Array, issue_open.assignees
    assert_equal 1, issue_open.assignees.size
    assert_instance_of ActiveProject::Resources::User, issue_open.assignees.first
    assert_equal "m1", issue_open.assignees.first.id

    assert_kind_of Array, issue_progress.assignees
    assert_empty issue_progress.assignees

    assert_kind_of Array, issue_closed_list.assignees
    assert_equal 2, issue_closed_list.assignees.size
    assert_instance_of ActiveProject::Resources::User, issue_closed_list.assignees[0]
    assert_instance_of ActiveProject::Resources::User, issue_closed_list.assignees[1]
    assert_equal %w[m1 m2], issue_closed_list.assignees.map(&:id).sort

    assert_kind_of Array, issue_archived.assignees
    assert_empty issue_archived.assignees

    assert_kind_of Array, issue_unmapped.assignees
    assert_equal 1, issue_unmapped.assignees.size
    assert_instance_of ActiveProject::Resources::User, issue_unmapped.assignees.first
    assert_equal "m3", issue_unmapped.assignees.first.id
    # Teardown will restore the original config saved by the base setup
  end

  test "#update_issue moves card to correct list based on mapped status" do
    board_id = "BOARD_WITH_MAPPING_UPDATE"
    card_id_to_update = ENV.fetch("TRELLO_TEST_CARD_ID_FOR_STATUS_UPDATE", "YOUR_CARD_ID_STATUS")
    list_open_id = "LIST_OPEN_UPDATE"
    list_progress_id = "LIST_PROGRESS_UPDATE"

    if card_id_to_update.include?("YOUR_CARD_ID")
      # skip("Set TRELLO_TEST_CARD_ID_FOR_STATUS_UPDATE environment variable to record VCR cassette.")
    end

    # Configure status mappings specifically for this test
    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: @api_key, api_token: @api_token do |trello_config|
        trello_config.status_mappings = {
          board_id => {
            list_open_id => :open,
            list_progress_id => :in_progress
          }
        }
      end
    end

    # Re-initialize adapter to pick up new config for this test
    ActiveProject.reset_adapters # Clear memoized instance
    adapter_for_test = ActiveProject.adapter(:trello)

    VCR.use_cassette("trello_adapter/update_issue_mapped_status") do
      # Mock the find_issue call within update_issue to provide the board_id
      mock_find_issue_response = { id: card_id_to_update, idBoard: board_id, name: "Test Card", idList: list_open_id,
                                   closed: false, idMembers: [] }.to_json
      stub_request(:get, %r{.*cards/#{card_id_to_update}\?fields=.*list=true.*})
        .to_return(status: 200, body: mock_find_issue_response, headers: { "Content-Type" => "application/json" })

      # Mock the PUT response to include the new list ID and some assignee data
      mock_put_response_body = {
        id: card_id_to_update, name: "Card Title", idList: list_progress_id, closed: false, idBoard: board_id, idMembers: [ "m1" ]
      }.to_json
      stub_request(:put, %r{.*cards/#{card_id_to_update}.*})
        .with(query: hash_including({ "idList" => list_progress_id }))
        .to_return(status: 200, body: mock_put_response_body, headers: { "Content-Type" => "application/json" })

      updated_issue = adapter_for_test.update_issue(card_id_to_update, { status: :in_progress })

      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      # VCR interaction should show PUT with idList=LIST_PROGRESS_UPDATE
      assert_equal list_progress_id, updated_issue.raw_data["idList"]
      assert_equal :in_progress, updated_issue.status
      assert_kind_of Array, updated_issue.assignees
      assert_instance_of ActiveProject::Resources::User, updated_issue.assignees.first
      assert_equal "m1", updated_issue.assignees.first.id
    end
    # Teardown will restore the original config saved by the base setup
  end
end
