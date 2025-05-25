# frozen_string_literal: true

require "test_helper"

class BasecampWebhookTest < ActiveSupport::TestCase
  def setup
    # Webhook parsing doesn't need real credentials or complex config,
    # but the adapter now requires a config object.
    # We configure it minimally here.
    ActiveProject.configure do |config|
      config.add_adapter :basecamp, :primary, account_id: "DUMMY_ACCOUNT_ID", access_token: "DUMMY_ACCESS_TOKEN"
    end
    @adapter = ActiveProject.adapter(:basecamp)
    # Clear memoized adapter instance
    ActiveProject.reset_adapters
  end

  def teardown
    # Reset config
    ActiveProject.configure do |config|
      config.add_adapter :basecamp, :primary, account_id: "DUMMY_ACCOUNT_ID", access_token: "DUMMY_ACCESS_TOKEN"
    end
    ActiveProject.reset_adapters
  end

  test "parses todo_created webhook" do
    payload = {
      "kind" => "todo_created",
      "created_at" => Time.now.iso8601,
      "creator" => { "id" => 1, "name" => "Test User", "email_address" => "test@example.com" },
      "recording" => {
        "id" => 12_345, "status" => "created", "type" => "Todo",
        "bucket" => { "id" => 100, "type" => "Project" },
        "parent" => { "id" => 50, "type" => "Todolist" },
        "content" => "New Todo",
        "assignees" => []
        # ... other todo fields
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_created, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal 12_345, event.event_object_id
    assert_nil event.object_key
    assert_equal 100, event.project_id
    assert_equal 1, event.actor.id # Access ID via User resource
    assert_equal :basecamp, event.adapter_source
    assert_equal JSON.parse(payload), event.raw_data
  end

  test "parses todo_completion_changed webhook" do
    payload = {
      "kind" => "todo_completion_changed",
      "created_at" => Time.now.iso8601,
      "creator" => { "id" => 2, "name" => "Completer User", "email_address" => "completer@example.com" },
      "recording" => {
        "id" => 12_346, "status" => "updated", "type" => "Todo",
        "bucket" => { "id" => 101, "type" => "Project" },
        "completed" => true
        # ... other todo fields
      },
      "details" => { "completed" => true } # Details might contain change info
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_updated, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal 12_346, event.event_object_id
    assert_equal 101, event.project_id
    assert_equal 2, event.actor.id # Access ID via User resource
    # Changes hash parsing not implemented in this basic parser
    assert_nil event.changes
  end

  test "parses comment_created webhook" do
    payload = {
      "kind" => "comment_created",
      "created_at" => Time.now.iso8601,
      "creator" => { "id" => 3, "name" => "Commenter", "email_address" => "commenter@example.com" },
      "recording" => {
        "id" => 5678, "status" => "created", "type" => "Comment",
        "bucket" => { "id" => 102, "type" => "Project" },
        "parent" => { "id" => 12_347, "type" => "Todo" }, # Parent is the Todo
        "content" => "<div>A comment</div>"
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :comment_added, event.event_type
    assert_equal :comment, event.object_kind
    assert_equal 5678, event.event_object_id
    assert_equal 102, event.project_id
    assert_equal 3, event.actor.id # Access ID via User resource
  end

  # Add tests for other kinds like comment_content_changed, todo_assignment_changed, etc.
end
