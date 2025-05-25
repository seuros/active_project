# frozen_string_literal: true

require "test_helper"
require "ostruct"

class GithubProjectAdapterInterfaceTest < ActiveSupport::TestCase
  def setup
    # Mock configuration for testing interface only
    config = ActiveProject::Configurations::GithubConfiguration.new(
      access_token: "ghp_" + "x" * 32  # Valid GitHub PAT format for testing
    )
    @adapter = ActiveProject::Adapters::GithubProjectAdapter.new(config: config)
  end

  test "#adapter_type returns correct symbol" do
    assert_equal :github_project, @adapter.send(:adapter_type)
  end

  test "#update_issue with base interface signature requires project_id in context" do
    item_id = "test_item_id"

    error = assert_raises(ArgumentError) do
      @adapter.update_issue(item_id, { title: "New Title" }, {})
    end
    assert_match(/requires :project_id in context/, error.message)
  end

  test "#delete_issue with base interface signature requires project_id in context" do
    item_id = "test_item_id"

    error = assert_raises(ArgumentError) do
      @adapter.delete_issue(item_id, {})
    end
    assert_match(/requires :project_id in context/, error.message)
  end

  test "#update_issue accepts project_id in context" do
    item_id = "test_item_id"
    project_id = "test_project_id"

    # Mock the internal method to avoid actual API calls
    @adapter.define_singleton_method(:update_issue_original) do |_proj_id, mock_item_id, attrs|
      OpenStruct.new(id: mock_item_id, title: attrs[:title])
    end

    result = @adapter.update_issue(item_id, { title: "New Title" }, { project_id: project_id })
    assert_equal "New Title", result.title
  end

  test "#delete_issue accepts project_id in context" do
    item_id = "test_item_id"
    project_id = "test_project_id"

    # Mock the internal method to avoid actual API calls
    @adapter.define_singleton_method(:delete_issue_original) do |_proj_id, _mock_item_id|
      true
    end

    result = @adapter.delete_issue(item_id, { project_id: project_id })
    assert_equal true, result
  end
end
