# frozen_string_literal: true

require "test_helper"
require_relative "github_repo_adapter_base_test"

class GithubRepoAdapterConnectionTest < GithubRepoAdapterBaseTest
  def test_initialize_with_valid_config
    assert_instance_of ActiveProject::Adapters::GithubRepoAdapter, @adapter
  end

  def test_initialize_with_missing_owner
    error = assert_raises(ArgumentError) do
      ActiveProject.configure do |config|
        config.add_adapter :github_repo, {
          repo: @repo,
          access_token: @access_token
        }
      end
      ActiveProject.adapter(:github_repo)
    end

    assert_match(/GithubRepoAdapter configuration requires :owner/, error.message)
  end

  def test_initialize_with_missing_repo
    error = assert_raises(ArgumentError) do
      ActiveProject.configure do |config|
        config.add_adapter :github_repo, {
          owner: @owner,
          access_token: @access_token
        }
      end
      ActiveProject.adapter(:github_repo)
    end

    assert_match(/GithubRepoAdapter configuration requires :repo/, error.message)
  end

  def test_initialize_with_missing_access_token
    error = assert_raises(ArgumentError) do
      ActiveProject.configure do |config|
        config.add_adapter :github_repo, {
          owner: @owner,
          repo: @repo
        }
      end
      ActiveProject.adapter(:github_repo)
    end

    assert_match(/GithubRepoAdapter configuration requires :access_token/, error.message)
  end

  def test_connected_returns_true_with_valid_credentials
    VCR.use_cassette("github_repo_adapter/connection_success") do
      assert @adapter.connected?
    end
  end

  def test_connected_returns_false_with_invalid_credentials
    ActiveProject.configure do |config|
      config.add_adapter :github_repo, {
        owner: @owner,
        repo: @repo,
        access_token: "invalid_token"
      }
    end

    invalid_adapter = ActiveProject.adapter(:github_repo)

    VCR.use_cassette("github_repo_adapter/authentication_error") do
      refute invalid_adapter.connected?
    end
  end

  def test_get_current_user_returns_user_object
    VCR.use_cassette("github_repo_adapter/get_current_user") do
      user = @adapter.get_current_user

      assert_instance_of ActiveProject::Resources::User, user
      assert_equal :github, user.adapter_source
      assert user.id.present?
      assert user.name.present?
    end
  end

  def test_get_current_user_raises_authentication_error_with_invalid_token
    ActiveProject.configure do |config|
      config.add_adapter :github_repo, {
        owner: @owner,
        repo: @repo,
        access_token: "invalid_token"
      }
    end

    invalid_adapter = ActiveProject.adapter(:github_repo)

    VCR.use_cassette("github_repo_adapter/get_current_user_authentication_error") do
      assert_raises(ActiveProject::AuthenticationError) do
        invalid_adapter.get_current_user
      end
    end
  end
end
