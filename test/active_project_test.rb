# frozen_string_literal: true

require "test_helper"

class ActiveProjectModuleTest < ActiveSupport::TestCase
  def setup
    # Clear any existing configuration and adapters before each test
    ActiveProject.instance_variable_set(:@configuration, nil)
    ActiveProject.instance_variable_set(:@adapters, nil)
  end

  def teardown
    # Ensure configuration is reset after tests
    ActiveProject.instance_variable_set(:@configuration, nil)
    ActiveProject.instance_variable_set(:@adapters, nil)
  end

  test ".configure yields configuration object" do
    yielded_config = nil
    ActiveProject.configure do |config|
      yielded_config = config
    end
    assert_instance_of ActiveProject::Configuration, yielded_config
  end

  test ".configuration returns the same configuration object" do
    config1 = ActiveProject.configuration
    config2 = ActiveProject.configuration
    assert_same config1, config2
  end

  test ".adapter returns correct adapter instance" do
    # Configure dummy adapters
    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: "key", api_token: "token"
      config.add_adapter :jira, site_url: "url", username: "user", api_token: "token"
      config.add_adapter :basecamp, account_id: "id", access_token: "token"
    end

    trello_adapter = ActiveProject.adapter(:trello)
    jira_adapter = ActiveProject.adapter(:jira)
    basecamp_adapter = ActiveProject.adapter(:basecamp)

    assert_instance_of ActiveProject::Adapters::TrelloAdapter, trello_adapter
    assert_instance_of ActiveProject::Adapters::JiraAdapter, jira_adapter
    assert_instance_of ActiveProject::Adapters::BasecampAdapter, basecamp_adapter

    # Verify config was passed
    assert_equal "key", trello_adapter.config.api_key
    assert_equal "url", jira_adapter.config.options[:site_url]
    assert_equal "id", basecamp_adapter.config.options[:account_id]
  end

  test ".adapter memoizes adapter instances" do
    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: "key", api_token: "token"
    end

    adapter1 = ActiveProject.adapter(:trello)
    adapter2 = ActiveProject.adapter(:trello)

    assert_same adapter1, adapter2
  end

  test ".adapter raises ArgumentError if adapter not configured" do
    assert_raises(ArgumentError, /Configuration for adapter ':not_configured' not found/) do
      ActiveProject.adapter(:not_configured)
    end
  end

  test ".adapter raises LoadError for unknown adapter name" do
    # Configure a dummy entry to bypass the config check
    ActiveProject.configure do |config|
      config.add_adapter :unknown_adapter_type, some_option: true
    end

    assert_raises(LoadError, /Could not find adapter class ActiveProject::Adapters::Unknown_adapter_typeAdapter/) do
      ActiveProject.adapter(:unknown_adapter_type)
    end
  end
end
