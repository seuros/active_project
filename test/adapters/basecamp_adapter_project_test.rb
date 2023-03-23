# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

# Tests for Basecamp Adapter Project operations.
class BasecampAdapterProjectTest < BasecampAdapterBaseTest
  TEST_BC_DELETE_PROJECT_ID = 41808873 # Static project for deletion test

  test "#list_projects returns an array of Project structs" do
    VCR.use_cassette("basecamp_adapter/list_projects") do
      projects = @adapter.list_projects

      assert_instance_of Array, projects
      unless projects.empty?
        assert_instance_of ActiveProject::Resources::Project, projects.first
        assert_equal :basecamp, projects.first.adapter_source
        assert projects.first.id
        assert projects.first.name
      end
    end
  end

  test "#find_project returns a Project struct for existing project" do
    project_id_for_test = "41789030"

    VCR.use_cassette("basecamp_adapter/find_project_success") do
      project = @adapter.find_project(project_id_for_test)

      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal project_id_for_test.to_i, project.id
      assert_equal :basecamp, project.adapter_source
      assert project.name
    end
  end

  test "#find_project raises NotFoundError for non-existent project" do
    VCR.use_cassette("basecamp_adapter/find_project_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_project("999999999") # Highly unlikely ID
      end
    end
  end

  test "#create_project creates a new project" do
    # This test still needs dynamic creation, but ensure cleanup
    created_project = nil
    project_name = "Test Project via ActiveProject 1700000000"
    begin
      VCR.use_cassette("basecamp_adapter/create_project_success_dynamic_#{project_name.parameterize}") do # Dynamic cassette
        attributes = { name: project_name, description: "Test project created by the gem." }
        created_project = @adapter.create_project(attributes)

        assert_instance_of ActiveProject::Resources::Project, created_project
        assert_equal project_name, created_project.name
        assert created_project.id
      end
    ensure
      # Cleanup the dynamically created project
      if created_project&.id && @adapter
        begin
          # Use a dynamic cassette name for cleanup too
          VCR.use_cassette("basecamp_adapter/delete_project_cleanup_dynamic_#{created_project.id}") do
            @adapter.delete_project(created_project.id)
          end
        rescue => e
          puts "[WARN] Failed to cleanup created project #{created_project.id}: #{e.message}"
        end
      end
    end
  end

  test "#create_project raises ArgumentError with missing required attributes" do
    assert_raises(ArgumentError, /Missing required attribute/) do
      @adapter.create_project(description: "Incomplete Project") # Missing name
    end
  end

  # Note: Basecamp doesn't really have validation errors like duplicate names
  # for project creation via API in the same way Jira does for keys.
  # Skipping duplicate name test.

  test "#delete_project successfully archives (trashes) an existing project" do
    project_id_to_delete = TEST_BC_DELETE_PROJECT_ID # Use static ID

    # Ensure the project exists before trying to delete (optional, good practice)
    VCR.use_cassette("basecamp_adapter/delete_project_find_static_#{project_id_to_delete}") do
      begin
        @adapter.find_project(project_id_to_delete)
      rescue ActiveProject::NotFoundError
        # If not found, try to un-trash it first, as it might be left over from a previous run
        begin
          VCR.use_cassette("basecamp_adapter/delete_project_untrash_static_#{project_id_to_delete}", record: :new_episodes) do
            puts "Static project #{project_id_to_delete} not found, attempting to un-trash..."
            # Basecamp API to un-trash is PUT /projects/:id/trash/recover.json
            @adapter.untrash_project(project_id_to_delete)
            puts "  Attempted un-trash."
          end
          # Try finding again after un-trashing
          @adapter.find_project(project_id_to_delete)
        rescue => e
          skip "Static project ID #{project_id_to_delete} not found and could not be recovered for deletion test: #{e.message}"
        end
      end
    end

    # Now archive (delete) it using a static cassette name
    VCR.use_cassette("basecamp_adapter/delete_project_success_static_#{project_id_to_delete}") do
      result = @adapter.delete_project(project_id_to_delete)
      assert result, "delete_project should return true on success"
    end

    # Verify archiving by trying to find it again (should raise NotFoundError)
    # VCR.use_cassette("basecamp_adapter/delete_project_verify_static_#{project_id_to_delete}") do
    #    assert_raises(ActiveProject::NotFoundError) do
    #      @adapter.find_project(project_id_to_delete)
    #    end
    # end
    # Note: To fully restore state for next run, un-trash the project here or manually.
    # Adding automatic un-trashing for simplicity.
    VCR.use_cassette("basecamp_adapter/delete_project_untrash_static_#{project_id_to_delete}") do
      @adapter.untrash_project(project_id_to_delete)
    end
  end

  test "#delete_project raises NotFoundError for non-existent project" do
    VCR.use_cassette("basecamp_adapter/delete_project_not_found_static") do # Static cassette name
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_project("999999999") # Highly unlikely ID
      end
    end
  end
end
