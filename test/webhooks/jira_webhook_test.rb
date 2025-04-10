# frozen_string_literal: true

require "test_helper"
# Load config base
# Load event class
# Load user resource for actor mapping

class JiraWebhookTest < ActiveSupport::TestCase
  def setup
    # Webhook parsing doesn't need real credentials or complex config,
    # but the adapter now requires a config object.
    # We configure it minimally here.
    ActiveProject.configure do |config|
      config.add_adapter :jira, :primary, site_url: "dummy", username: "dummy", api_token: "dummy"
    end
    @adapter = ActiveProject.adapter(:jira)
    # Clear memoized adapter instance
    ActiveProject.reset_adapters
  end

  def teardown
    # Reset config
    ActiveProject.configure do |config|
      config.add_adapter :jira, :primary, {}
    end
    ActiveProject.reset_adapters
  end

  test "parses jira:issue_created webhook" do
    payload = {
      "timestamp" => Time.now.to_i * 1000,
      "webhookEvent" => "jira:issue_created",
      "user" => { "accountId" => "user1", "displayName" => "Test User", "emailAddress" => "test@example.com" },
      "issue" => {
        "id" => "10001", "key" => "PROJ-123",
        "fields" => {
          "project" => { "id" => "10000", "key" => "PROJ" },
          "summary" => "New Issue Created"
          # ... other fields ...
        }
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_created, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal "10001", event.event_object_id
    assert_equal "PROJ-123", event.object_key
    assert_equal 10_000, event.project_id
    assert_equal "user1", event.actor.id # Access ID via User resource
    assert_equal :jira, event.adapter_source
    assert_equal JSON.parse(payload), event.raw_data
  end

  test "parses jira:issue_updated webhook with changelog" do
    payload = {
      "timestamp" => Time.now.to_i * 1000,
      "webhookEvent" => "jira:issue_updated",
      "user" => { "accountId" => "user2", "displayName" => "Updater User", "emailAddress" => "updater@example.com" },
      "issue" => {
        "id" => "10002", "key" => "PROJ-124",
        "fields" => { "project" => { "id" => "10000", "key" => "PROJ" } }
      },
      "changelog" => {
        "id" => "10100",
        "items" => [
          { "field" => "status", "fromString" => "To Do", "toString" => "In Progress" },
          { "fieldId" => "assignee", "from" => nil, "to" => "user1" }
        ]
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :issue_updated, event.event_type
    assert_equal :issue, event.object_kind
    assert_equal "10002", event.event_object_id
    assert_equal "PROJ-124", event.object_key
    assert_equal 10_000, event.project_id
    assert_equal "user2", event.actor.id # Access ID via User resource
    assert_equal({ status: [ "To Do", "In Progress" ], assignee: [ nil, "user1" ] }, event.changes)
  end

  test "parses comment_created webhook" do
    payload = {
      "timestamp" => Time.now.to_i * 1000,
      "webhookEvent" => "comment_created",
      "comment" => {
        "id" => "10200",
        "author" => { "accountId" => "user3", "displayName" => "Commenter", "emailAddress" => "commenter@example.com" },
        "body" => { "type" => "doc", "version" => 1, "content" => [] }, # Simplified ADF
        "created" => Time.now.iso8601
      },
      "issue" => { # Issue context is usually included
        "id" => "10003", "key" => "PROJ-125",
        "fields" => { "project" => { "id" => "10000", "key" => "PROJ" } }
      }
    }.to_json

    event = @adapter.parse_webhook(payload)

    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :comment_added, event.event_type
    assert_equal :comment, event.object_kind
    assert_equal "10200", event.event_object_id
    assert_nil event.object_key
    assert_equal 10_000, event.project_id
    assert_equal "user3", event.actor.id # Access ID via User resource
  end

  # Add tests for comment_updated, issue_deleted, etc.
end
