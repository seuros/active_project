# frozen_string_literal: true

require "test_helper"

class ActiveProjectModuleTest < ActiveSupport::TestCase
  def teardown
    ActiveProject.reset_adapters
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
      config.add_adapter :trello, :primary, key: "DUMMY_KEY", token: "DUMMY_TOKEN"
      config.add_adapter :jira, site_url: "DUMMY_SITE_URL", username: "DUMMY_USERNAME", api_token: "DUMMY_API_TOKEN"
      config.add_adapter :basecamp, account_id: "DUMMY_ACCOUNT_ID", access_token: "DUMMY_ACCESS_TOKEN"
      config.add_adapter :github_repo, owner: "owner", repo: "repo", access_token: "DUMMY_ACCESS_TOKEN"
    end

    trello_adapter = ActiveProject.adapter(:trello)
    jira_adapter = ActiveProject.adapter(:jira)
    basecamp_adapter = ActiveProject.adapter(:basecamp)
    github_repo_adapter = ActiveProject.adapter(:github_repo)

    assert_instance_of ActiveProject::Adapters::TrelloAdapter, trello_adapter
    assert_instance_of ActiveProject::Adapters::JiraAdapter, jira_adapter
    assert_instance_of ActiveProject::Adapters::BasecampAdapter, basecamp_adapter
    assert_instance_of ActiveProject::Adapters::GithubRepoAdapter, github_repo_adapter

    # Verify config was passed
    assert_equal "DUMMY_KEY", trello_adapter.config.key
    assert_equal "DUMMY_SITE_URL", jira_adapter.config.options[:site_url]
    assert_equal "DUMMY_ACCOUNT_ID", basecamp_adapter.config.options[:account_id]
    assert_equal "owner", github_repo_adapter.config.options[:owner]
    assert_equal "repo", github_repo_adapter.config.options[:repo]
  end

  test ".adapter memoizes adapter instances" do
    ActiveProject.configure do |config|
      config.add_adapter :trello, :primary, key: "DUMMY_KEY", token: "DUMMY_TOKEN"
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
