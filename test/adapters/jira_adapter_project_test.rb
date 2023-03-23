# frozen_string_literal: true

require_relative "jira_adapter_base_test"

# Tests for Jira Adapter Project operations using static data.
class JiraAdapterProjectTest < JiraAdapterBaseTest
  test "#list_projects returns an array of Project structs" do
    VCR.use_cassette("jira_adapter/list_projects_static") do # New cassette name
      projects = @adapter.list_projects

      assert_instance_of Array, projects
      # Check if our static project is included
      lac_project = projects.find { |p| p.key == TEST_JIRA_PROJECT_KEY }
      refute_nil lac_project, "Expected to find project #{TEST_JIRA_PROJECT_KEY} in the list"
      assert_instance_of ActiveProject::Resources::Project, lac_project
      assert_equal :jira, lac_project.adapter_source
      assert lac_project.id
      assert lac_project.name
    end
  end

  test "#find_project returns a Project struct for existing project" do
    project_key_for_test = TEST_JIRA_PROJECT_KEY # Use constant

    VCR.use_cassette("jira_adapter/find_project_success_static") do # New cassette name
      project = @adapter.find_project(project_key_for_test)

      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal project_key_for_test, project.key
      assert_equal :jira, project.adapter_source
      assert_equal 10004, project.id # Check against known ID for LAC
      assert project.name
    end
  end

  test "#find_project raises NotFoundError for non-existent project" do
    VCR.use_cassette("jira_adapter/find_project_not_found_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_project("NONEXISTENTPROJECTKEY")
      end
    end
  end

  test "#create_project creates a new project" do
    # This test inherently needs to create something dynamic.
    # We'll keep using dynamic creation but ensure cleanup.
    test_project = nil
    project_key = "APDEL6699" # Hardcoded key
    begin
      VCR.use_cassette("jira_adapter/create_project_success_dynamic") do
        attributes = {
          key: project_key,
          name: "Test Project Create APDEL6699", # Hardcoded key
          project_type_key: ENV.fetch("JIRA_TEST_PROJECT_TYPE_KEY", "software"),
          lead_account_id: ENV["JIRA_TEST_LEAD_ACCOUNT_ID"] || "5e9360a3088a7e0c0f4c55f3",
          description: "Temp project for dynamic create test APDEL6699", # Hardcoded key
          assignee_type: "PROJECT_LEAD"
        }
        test_project = @adapter.create_project(attributes)

        assert_instance_of ActiveProject::Resources::Project, test_project
        assert_equal project_key, test_project.key
        assert test_project.id
      end
    ensure
      # Cleanup the dynamically created project
      if test_project&.key && @adapter
        VCR.use_cassette("jira_adapter/delete_project_cleanup_dynamic_APDEL6699") do # Hardcoded key
          deleted = @adapter.delete_project(test_project.key)
        end
      end
    end
  end

  test "#create_project raises ArgumentError with missing required attributes" do
    assert_raises(ArgumentError, /Missing required attributes/) do
      @adapter.create_project(name: "Incomplete Project") # Missing key, type, lead
    end
  end

  test "#create_project raises ValidationError with invalid data (e.g., duplicate key)" do
    # Use the static key which should already exist
    project_key_for_test = TEST_JIRA_PROJECT_KEY

    VCR.use_cassette("jira_adapter/create_project_duplicate_key_static") do # New cassette name
      attributes = {
        key: project_key_for_test,
        name: "Attempt to Duplicate #{project_key_for_test}",
        project_type_key: ENV.fetch("JIRA_TEST_PROJECT_TYPE_KEY", "software"),
        lead_account_id: ENV["JIRA_TEST_LEAD_ACCOUNT_ID"] || "5e9360a3088a7e0c0f4c55f3"
      }
      assert_raises(ActiveProject::ValidationError, /already exists|uses this project key/) do
        @adapter.create_project(attributes)
      end
    end
  end

  test "#delete_project successfully deletes an existing project" do
    # This test also needs dynamic creation/deletion
    test_project = nil
    project_key = "APDEL6699" # Hardcoded key
    begin
      # Create project first
      VCR.use_cassette("jira_adapter/delete_project_create_dynamic_APDEL6699") do # Hardcoded key
        attributes = {
          key: project_key,
          name: "Test Project Delete APDEL6699", # Hardcoded key
          project_type_key: ENV.fetch("JIRA_TEST_PROJECT_TYPE_KEY", "software"),
          lead_account_id: ENV["JIRA_TEST_LEAD_ACCOUNT_ID"] || "5e9360a3088a7e0c0f4c55f3"
        }
        test_project = @adapter.create_project(attributes)
        refute_nil test_project, "Failed to create project for deletion test"
      end

      # Now delete it
      VCR.use_cassette("jira_adapter/delete_project_success_dynamic_APDEL6699") do # Hardcoded key
        result = @adapter.delete_project(test_project.key)
        assert result, "delete_project should return true on success"
      end

      # Verify deletion by trying to find it again
      VCR.use_cassette("jira_adapter/delete_project_verify_not_found_dynamic_APDEL6699") do # Hardcoded key
        assert_raises(ActiveProject::NotFoundError) do
          @adapter.find_project(test_project.key)
        end
      end
    ensure
      # Cleanup attempt (might fail if deletion already happened or project never created)
      if project_key && @adapter
        VCR.use_cassette("jira_adapter/delete_project_final_cleanup_dynamic_APDEL6699") do
          @adapter.delete_project(project_key)
        end
      end
    end
  end

  test "#delete_project raises NotFoundError for non-existent project" do
    VCR.use_cassette("jira_adapter/delete_project_not_found_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_project("NONEXISTENTPROJECTKEY")
      end
    end
  end
end
