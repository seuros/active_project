# frozen_string_literal: true

require "test_helper"
require_relative "github_adapter_base_test"

class GithubAdapterProjectTest < GithubAdapterBaseTest
  def test_list_projects
    VCR.use_cassette("github_adapter/list_projects") do
      projects = @adapter.list_projects
      
      assert_kind_of Array, projects
      assert_equal 1, projects.length
      
      project = projects.first
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal @project_id, project.key
      assert_equal @project_full_name, project.name
      assert_equal :github, project.adapter_source
    end
  end
  
  def test_find_project_by_name
    VCR.use_cassette("github_adapter/find_project_by_name") do
      project = @adapter.find_project(@project_id)
      
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal @project_id, project.key
      assert_equal @project_full_name, project.name
      assert_equal :github, project.adapter_source
    end
  end
  
  def test_find_project_by_full_name
    VCR.use_cassette("github_adapter/find_project_by_full_name") do
      project = @adapter.find_project(@project_full_name)
      
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal @project_id, project.key
      assert_equal @project_full_name, project.name
      assert_equal :github, project.adapter_source
    end
  end
  
  def test_find_project_not_found
    VCR.use_cassette("github_adapter/find_project_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_project("nonexistent-repo-#{Time.now.to_i}")
      end
    end
  end
  
  def test_project_factory
    VCR.use_cassette("github_adapter/project_factory") do
      projects_factory = @adapter.projects
      assert_instance_of ActiveProject::ResourceFactory, projects_factory
      
      # Test that we can fetch projects via the factory
      all_projects = projects_factory.all
      assert_kind_of Array, all_projects
      assert all_projects.all? { |p| p.is_a?(ActiveProject::Resources::Project) }
      
      # Test find method on the factory
      project = projects_factory.find(@project_id)
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal @project_id, project.key
    end
  end
  
  # Only run this test if explicitly enabled, as it creates a real repository
  def test_create_project
    skip "Skip repository creation test unless ENABLE_REPO_CREATION=true" unless ENV["ENABLE_REPO_CREATION"] == "true"
    
    timestamp = Time.now.to_i
    repo_name = "test-repo-#{timestamp}"
    
    VCR.use_cassette("github_adapter/create_project") do
      project = @adapter.create_project({
        name: repo_name,
        description: "Test repository created via ActiveProject tests",
        private: true
      })
      
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal repo_name, project.key
      assert_equal "#{@owner}/#{repo_name}", project.name
      assert_equal :github, project.adapter_source
      
      # Clean up - delete the repository we just created
      delete_test_repository(project.key)
    end
  end
  
  # Only run this test if explicitly enabled, as it deletes a real repository
  def test_delete_project
    skip "Skip repository deletion test unless ENABLE_REPO_DELETION=true" unless ENV["ENABLE_REPO_DELETION"] == "true"
    
    # First create a repository to delete
    timestamp = Time.now.to_i
    repo_name = "delete-test-repo-#{timestamp}"
    
    VCR.use_cassette("github_adapter/delete_project") do
      # Create a test repository
      project = @adapter.create_project({
        name: repo_name,
        description: "Test repository for deletion via ActiveProject",
        private: true
      })
      
      # Delete the repository
      result = @adapter.delete_project(project.key)
      assert result
      
      # Verify the repository is gone
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_project(project.key)
      end
    end
  end
end