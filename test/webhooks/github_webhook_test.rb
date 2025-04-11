# frozen_string_literal: true

require "test_helper"
require_relative "../adapters/github_adapter_base_test"

class GithubWebhookTest < GithubAdapterBaseTest
  def setup
    super
    @webhook_secret = "test_webhook_secret"
    
    # Configure adapter with webhook secret
    ActiveProject.configure do |config|
      config.add_adapter :github, {
        owner: @owner,
        repo: @repo,
        access_token: @access_token,
        webhook_secret: @webhook_secret
      }
    end
    
    @adapter = ActiveProject.adapter(:github)
  end
  
  def test_verify_webhook_signature_valid
    payload = '{"action":"opened","issue":{"number":1}}'
    
    # Create a valid signature
    signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      @webhook_secret,
      payload
    )
    signature_header = "sha256=#{signature}"
    
    # Test verification
    assert @adapter.verify_webhook_signature(payload, signature_header)
  end
  
  def test_verify_webhook_signature_invalid
    payload = '{"action":"opened","issue":{"number":1}}'
    invalid_signature = "sha256=fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    
    # Test verification with invalid signature
    refute @adapter.verify_webhook_signature(payload, invalid_signature)
  end
  
  def test_verify_webhook_signature_empty_secret
    # Configure adapter with empty webhook secret
    ActiveProject.reset_adapters
    ActiveProject.configure do |config|
      config.add_adapter :github, {
        owner: @owner,
        repo: @repo,
        access_token: @access_token,
        webhook_secret: ""
      }
    end
    
    adapter_with_empty_secret = ActiveProject.adapter(:github)
    payload = '{"action":"opened","issue":{"number":1}}'
    
    # When empty webhook secret is configured, verification should pass
    assert adapter_with_empty_secret.verify_webhook_signature(payload, "sha256=any_signature")
  end
  
  def test_verify_webhook_signature_nil_secret
    # Configure adapter with nil webhook secret
    ActiveProject.reset_adapters
    ActiveProject.configure do |config|
      config.add_adapter :github, {
        owner: @owner,
        repo: @repo,
        access_token: @access_token,
        webhook_secret: nil
      }
    end
    
    adapter_with_nil_secret = ActiveProject.adapter(:github)
    payload = '{"action":"opened","issue":{"number":1}}'
    
    # When nil webhook secret is configured, verification should pass
    assert adapter_with_nil_secret.verify_webhook_signature(payload, "sha256=any_signature")
  end
  
  def test_parse_webhook_issue_opened
    # Load sample webhook payload
    payload = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'github_webhook_issue_opened.json'))
    headers = { "X-GitHub-Event" => "issues" }
    
    # Parse webhook
    event = @adapter.parse_webhook(payload, headers)
    
    # Test event properties
    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :github, event.source
    assert_equal :issue_created, event.type
    assert_equal :issue, event.resource_type
    assert_equal "1", event.resource_id
    assert_equal "aviflombaum/test-repo", event.project_id
    
    # Test issue data
    issue = event.data[:issue]
    assert_instance_of ActiveProject::Resources::Issue, issue
    assert_equal "Test Issue", issue.title
    assert_equal "This is a test issue created via webhooks", issue.description
    assert_equal :open, issue.status
  end
  
  def test_parse_webhook_issue_closed
    # Load sample webhook payload
    payload = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'github_webhook_issue_closed.json'))
    headers = { "X-GitHub-Event" => "issues" }
    
    # Parse webhook
    event = @adapter.parse_webhook(payload, headers)
    
    # Test event properties
    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :github, event.source
    assert_equal :issue_closed, event.type
    assert_equal :issue, event.resource_type
    assert_equal "1", event.resource_id
    
    # Test issue data
    issue = event.data[:issue]
    assert_instance_of ActiveProject::Resources::Issue, issue
    assert_equal "Test Issue", issue.title
    assert_equal :closed, issue.status
  end
  
  def test_parse_webhook_comment_created
    # Load sample webhook payload
    payload = File.read(File.join(File.dirname(__FILE__), '..', 'fixtures', 'github_webhook_comment_created.json'))
    headers = { "X-GitHub-Event" => "issue_comment" }
    
    # Parse webhook
    event = @adapter.parse_webhook(payload, headers)
    
    # Test event properties
    assert_instance_of ActiveProject::WebhookEvent, event
    assert_equal :github, event.source
    assert_equal :comment_created, event.type
    assert_equal :comment, event.resource_type
    assert_equal "1234567891", event.resource_id
    
    # Test comment data
    comment = event.data[:comment]
    assert_instance_of ActiveProject::Resources::Comment, comment
    assert_equal "This is a test comment on the issue", comment.body
    
    # Test related issue
    issue = event.data[:issue]
    assert_instance_of ActiveProject::Resources::Issue, issue
    assert_equal "Test Issue", issue.title
  end
  
  def test_parse_webhook_unsupported_event
    payload = '{"action":"created","alert":{"number":1}}'
    headers = { "X-GitHub-Event" => "dependabot_alert" }
    
    # Test parsing of an unsupported event type
    event = @adapter.parse_webhook(payload, headers)
    assert_nil event
  end
  
  def test_parse_webhook_invalid_json
    payload = 'not valid json'
    headers = { "X-GitHub-Event" => "issues" }
    
    # Test parsing of invalid JSON
    event = @adapter.parse_webhook(payload, headers)
    assert_nil event
  end
end