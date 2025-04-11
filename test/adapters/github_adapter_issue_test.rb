# frozen_string_literal: true

require "test_helper"
require_relative "github_adapter_base_test"

class GithubAdapterIssueTest < GithubAdapterBaseTest
  def setup
    super
    @test_issue = nil
  end
  
  def teardown
    # Close any test issues we created
    if @test_issue && @test_issue.key
      VCR.use_cassette("github_adapter/teardown_close_issue_#{@test_issue.key}") do
        @adapter.update_issue(@test_issue.key, { status: :closed })
      end
    end
    
    super
  end
  
  def test_list_issues
    VCR.use_cassette("github_adapter/list_issues") do
      issues = @adapter.list_issues(@project_id)
      
      assert_kind_of Array, issues
      issues.each do |issue|
        assert_instance_of ActiveProject::Resources::Issue, issue
        assert_equal :github, issue.adapter_source
        assert issue.key.present?
        assert issue.title.present?
      end
    end
  end
  
  def test_list_issues_with_status_filter
    VCR.use_cassette("github_adapter/list_issues_with_status_filter") do
      # Test with 'open' status
      open_issues = @adapter.list_issues(@project_id, { status: 'open' })
      assert_kind_of Array, open_issues
      assert open_issues.all? { |i| i.status == :open }
      
      # Test with 'closed' status
      closed_issues = @adapter.list_issues(@project_id, { status: 'closed' })
      assert_kind_of Array, closed_issues
      assert closed_issues.all? { |i| i.status == :closed }
      
      # Test with 'all' status
      all_issues = @adapter.list_issues(@project_id, { status: 'all' })
      assert_kind_of Array, all_issues
      assert all_issues.size >= (open_issues.size + closed_issues.size)
    end
  end
  
  def test_list_issues_with_pagination
    VCR.use_cassette("github_adapter/list_issues_with_pagination") do
      # Get first page with 2 items
      page1 = @adapter.list_issues(@project_id, { per_page: 2, page: 1 })
      assert_kind_of Array, page1
      assert page1.size <= 2
      
      if page1.size == 2
        # Get second page
        page2 = @adapter.list_issues(@project_id, { per_page: 2, page: 2 })
        assert_kind_of Array, page2
        
        # Ensure we got different issues
        if page2.any?
          page1_keys = page1.map(&:key)
          page2_keys = page2.map(&:key)
          assert_empty page1_keys & page2_keys, "Expected pages to contain different issues"
        end
      end
    end
  end
  
  def test_find_issue
    # Create a test issue first
    VCR.use_cassette("github_adapter/create_issue_for_find_test") do
      @test_issue = create_test_issue("for_find_test")
      assert @test_issue, "Failed to create test issue"
    end
    
    # Now find the issue
    VCR.use_cassette("github_adapter/find_issue") do
      found_issue = @adapter.find_issue(@test_issue.key)
      
      assert_instance_of ActiveProject::Resources::Issue, found_issue
      assert_equal @test_issue.key, found_issue.key
      assert_equal @test_issue.title, found_issue.title
      assert_equal :github, found_issue.adapter_source
    end
  end
  
  def test_find_issue_not_found
    VCR.use_cassette("github_adapter/find_issue_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue("99999999")
      end
    end
  end
  
  def test_create_issue
    VCR.use_cassette("github_adapter/create_issue") do
      title = "Test Issue #{Time.now.to_i}"
      description = "This is a test issue created through the GitHub adapter"
      
      issue = @adapter.create_issue(@project_id, {
        title: title,
        description: description
      })
      
      @test_issue = issue # Store for teardown
      
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal title, issue.title
      assert_equal description, issue.description
      assert_equal :open, issue.status
      assert_equal @project_full_name, issue.project_id
    end
  end
  
  def test_create_issue_with_assignees
    VCR.use_cassette("github_adapter/create_issue_with_assignees") do
      # Get authenticated user for assignee
      current_user = @adapter.get_current_user
      
      title = "Test Issue with Assignee #{Time.now.to_i}"
      issue = @adapter.create_issue(@project_id, {
        title: title,
        description: "Testing issue creation with assignees",
        assignees: [current_user.name]
      })
      
      @test_issue = issue # Store for teardown
      
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal title, issue.title
      assert_equal :open, issue.status
      
      # Check that assignee was set
      assert_equal 1, issue.assignees.size
      assert_equal current_user.name, issue.assignees.first.name
    end
  end
  
  def test_update_issue_title
    # Create a test issue first
    VCR.use_cassette("github_adapter/create_issue_for_update_test") do
      @test_issue = create_test_issue("for_update_test")
      assert @test_issue, "Failed to create test issue"
    end
    
    # Update the issue title
    VCR.use_cassette("github_adapter/update_issue_title") do
      updated_title = "Updated Title #{Time.now.to_i}"
      updated_issue = @adapter.update_issue(@test_issue.key, {
        title: updated_title
      })
      
      assert_instance_of ActiveProject::Resources::Issue, updated_issue
      assert_equal updated_title, updated_issue.title
      assert_equal @test_issue.key, updated_issue.key
    end
  end
  
  def test_update_issue_status
    # Create a test issue first
    VCR.use_cassette("github_adapter/create_issue_for_status_update_test") do
      @test_issue = create_test_issue("for_status_update_test")
      assert @test_issue, "Failed to create test issue"
      assert_equal :open, @test_issue.status
    end
    
    # Close the issue
    VCR.use_cassette("github_adapter/update_issue_close") do
      closed_issue = @adapter.update_issue(@test_issue.key, {
        status: :closed
      })
      
      assert_instance_of ActiveProject::Resources::Issue, closed_issue
      assert_equal @test_issue.key, closed_issue.key
      assert_equal :closed, closed_issue.status
    end
    
    # Reopen the issue
    VCR.use_cassette("github_adapter/update_issue_reopen") do
      reopened_issue = @adapter.update_issue(@test_issue.key, {
        status: :open
      })
      
      assert_instance_of ActiveProject::Resources::Issue, reopened_issue
      assert_equal @test_issue.key, reopened_issue.key
      assert_equal :open, reopened_issue.status
    end
  end
  
  def test_update_issue_assignees
    # Create a test issue first
    VCR.use_cassette("github_adapter/create_issue_for_assignee_update_test") do
      @test_issue = create_test_issue("for_assignee_update_test")
      assert @test_issue, "Failed to create test issue"
    end
    
    # Get authenticated user for assignee
    VCR.use_cassette("github_adapter/get_user_for_assignee_update") do
      current_user = @adapter.get_current_user
      
      # Add assignee
      VCR.use_cassette("github_adapter/update_issue_add_assignee") do
        updated_issue = @adapter.update_issue(@test_issue.key, {
          assignees: [{ name: current_user.name }]
        })
        
        assert_instance_of ActiveProject::Resources::Issue, updated_issue
        assert_equal 1, updated_issue.assignees.size
        assert_equal current_user.name, updated_issue.assignees.first.name
      end
      
      # Remove assignee
      VCR.use_cassette("github_adapter/update_issue_remove_assignee") do
        updated_issue = @adapter.update_issue(@test_issue.key, {
          assignees: []
        })
        
        assert_instance_of ActiveProject::Resources::Issue, updated_issue
        assert_equal 0, updated_issue.assignees.size
      end
    end
  end
  
  def test_delete_issue
    # Create a test issue first
    VCR.use_cassette("github_adapter/create_issue_for_delete_test") do
      @test_issue = create_test_issue("for_delete_test")
      assert @test_issue, "Failed to create test issue"
      assert_equal :open, @test_issue.status
    end
    
    # Attempt to delete the issue (will close it instead)
    VCR.use_cassette("github_adapter/delete_issue") do
      result = @adapter.delete_issue(@test_issue.key)
      
      # Should return false since GitHub doesn't support true deletion
      assert_equal false, result
      
      # Check that the issue was closed instead
      closed_issue = @adapter.find_issue(@test_issue.key)
      assert_equal :closed, closed_issue.status
    end
  end
  
  def test_issue_factory
    VCR.use_cassette("github_adapter/issue_factory") do
      # Create a test issue first
      @test_issue = create_test_issue("for_factory_test")
      
      # Test the issues factory
      issues_factory = @adapter.issues
      assert_instance_of ActiveProject::ResourceFactory, issues_factory
      
      # Test that we can fetch issues via the factory
      all_issues = issues_factory.all(@project_id)
      assert_kind_of Array, all_issues
      assert all_issues.all? { |i| i.is_a?(ActiveProject::Resources::Issue) }
      
      # Test find method on the factory
      issue = issues_factory.find(@test_issue.key)
      assert_instance_of ActiveProject::Resources::Issue, issue
      assert_equal @test_issue.key, issue.key
    end
  end
end