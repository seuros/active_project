# frozen_string_literal: true

require "test_helper"
# Load config
# Load event class

class TrelloWebhookTest < ActiveSupport::TestCase
  def setup
    # Webhook parsing doesn't need real credentials or complex config,
    # but the adapter now requires a config object.
    # We configure it minimally here.
    ActiveProject.configure do |config|
      config.add_adapter :trello, :primary, key: "DUMMY_KEY", token: "DUMMY_TOKEN" do |trello_config|
        trello_config.status_mappings = {}
      end
    end
    @adapter = ActiveProject.adapter(:trello)
    # Clear memoized adapter instance
    ActiveProject.reset_adapters
  end

  def teardown
    # Reset config
    ActiveProject.configure do |config|
      config.add_adapter :trello, :primary, key: "DUMMY_KEY", token: "DUMMY_TOKEN"
    end
    ActiveProject.reset_adapters
  end

  test "parses createCard webhook" do
    payload = {
      "action" => {
        "id" => "action1", "type" => "createCard", "date" => Time.now.iso8601,
        "memberCreator" => { "id" => "member1", "fullName" => "Test User" },
        "data" => {
          "card" => { "id" => "card123", "idShort" => 12, "name" => "New Card" },
          "list" => { "id" => "list1", "name" => "To Do" },
          "board" => { "id" => "board1", "name" => "Test Board" }
        }
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_created, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal "card123", event.event_object_id
    assert_equal 12, event.object_key
    assert_equal "board1", event.project_id
    assert_equal "member1", event.actor.id # Access ID via User resource
    assert_equal :trello, event.adapter_source
    assert_equal JSON.parse(payload), event.raw_data
  end

  test "parses updateCard webhook (list change)" do
    payload = {
      "action" => {
        "id" => "action2", "type" => "updateCard", "date" => Time.now.iso8601,
        "memberCreator" => { "id" => "member1", "fullName" => "Test User" },
        "data" => {
          "card" => { "id" => "card123", "idShort" => 12, "idList" => "list2" },
          "listAfter" => { "id" => "list2", "name" => "Doing" },
          "listBefore" => { "id" => "list1", "name" => "To Do" },
          "board" => { "id" => "board1", "name" => "Test Board" },
          "old" => { "idList" => "list1" }
        }
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_updated, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal "card123", event.event_object_id
    assert_equal "board1", event.project_id
    assert_equal({ idList: %w[list1 list2] }, event.changes) # Check changes hash if implemented
  end

  test "parses commentCard webhook" do
    payload = {
      "action" => {
        "id" => "action3", "type" => "commentCard", "date" => Time.now.iso8601,
        "memberCreator" => { "id" => "member2", "fullName" => "Another User" },
        "data" => {
          "card" => { "id" => "card456", "idShort" => 45, "name" => "Card with Comment" },
          "board" => { "id" => "board2", "name" => "Another Board" },
          "text" => "This is a comment."
        }
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :comment_added, event.event_type
    assert_equal :comment, event.object_kind
    assert_equal "action3", event.event_object_id # Comment ID is the action ID
    assert_equal "board2", event.project_id
    assert_equal "member2", event.actor.id # Access ID via User resource
  end

  # Add more tests for other event types (addMemberToCard, update checkItem state, etc.)
end
