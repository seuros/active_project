# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
require_relative "../../lib/active_project/errors" # Explicitly require custom errors for this test file

class TrelloAdapterProjectTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Project (Board) Tests ---

  test "#list_projects returns an array of Project structs (Trello Boards)" do
    VCR.use_cassette("trello_adapter/list_projects") do
      projects = @adapter.list_projects # Corresponds to boards

      assert_instance_of Array, projects
      unless projects.empty?
        assert_instance_of ActiveProject::Resources::Project, projects.first
        assert_equal :trello, projects.first.adapter_source
        assert projects.first.id
        assert projects.first.name
        assert_nil projects.first.key
      end
    end
  end

  test "#find_project returns a Project struct for a valid board ID" do
    board_id_for_test = ENV.fetch("TRELLO_TEST_BOARD_ID", "YOUR_BOARD_ID_FOR_FIND_PROJECT")
    if board_id_for_test.include?("YOUR_BOARD_ID")
      skip("Set TRELLO_TEST_BOARD_ID environment variable to record VCR cassette for find_project.")
    end

    VCR.use_cassette("trello_adapter/find_project") do
      project = @adapter.find_project(board_id_for_test)
      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal :trello, project.adapter_source
      assert_equal board_id_for_test, project.id
      assert project.name
      assert_nil project.key
    end
  end


  test "#create_project creates a new board in Trello" do
    # No specific ENV vars needed here unless testing with specific org, etc.
    skip_if_missing_credentials # Use helper from base class

    skip "Skipping due to Trello 'Workspaces are full' error (account limit)"
    VCR.use_cassette("trello_adapter/create_project_success") do
      board_name = "Test Board via ActiveProject 1700000000"
      attributes = {
        name: board_name,
        description: "A test board created by the gem.",
        default_lists: false # Don't create default lists for cleaner testing
      }

      project = @adapter.create_project(attributes) # Project corresponds to Board

      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal :trello, project.adapter_source
      assert project.id
      assert_equal board_name, project.name
      assert_nil project.key # Trello doesn't use keys
      assert project.raw_data["url"] # Check for a typical Trello response field

      # Cleanup: Trello API allows closing/deleting boards.
      # Consider adding cleanup if necessary.
      # Example (requires implementing #delete_project or similar):
      # @adapter.delete_project(project.id) if project&.id
    end
  end

  test "#create_project raises ArgumentError with missing required attributes" do
    # No VCR needed
    attributes = {
      description: "Board without a name"
      # Missing name
    }
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_project(attributes)
    end
  end

  test "#create_project raises ValidationError with invalid data (e.g., invalid organization)" do
    skip_if_missing_credentials # Use helper from base class

    VCR.use_cassette("trello_adapter/create_project_error_workspaces_full") do
      attributes = {
        name: "Test Board Invalid Org 1700000000",
        idOrganization: "invalidOrgIdThatDoesNotExist" # Use an invalid Org ID
      }

      # Trello API should return a 400 or similar error
      assert_raises(ActiveProject::ValidationError, /invalid value for idOrganization|organization not found/) do
         @adapter.create_project(attributes)
      end
    end
  end

  # --- Deletion Tests ---

  test "#delete_project successfully deletes an existing board" do
    # Create a board specifically for this deletion test
    board_name = "AP Trello Delete Test 1700000000"
    created_board = nil
    VCR.use_cassette("trello_adapter/delete_project_create_step") do
    skip "Skipping due to Trello 'Workspaces are full' error (account limit)"
       skip_if_missing_credentials # Need credentials to create
       attributes = { name: board_name, default_lists: false } # Don't need default lists
       created_board = @adapter.create_project(attributes)
       refute_nil created_board, "Failed to create board for deletion test"
    end

    # Now delete it
    VCR.use_cassette("trello_adapter/delete_project_success") do
      skip_if_missing_credentials # Need credentials to delete
      result = @adapter.delete_project(created_board.id)
      assert result, "delete_project should return true on success"
    end

    # Verify deletion by trying to find it again
    VCR.use_cassette("trello_adapter/delete_project_verify_not_found") do
       skip_if_missing_credentials # Need credentials to find (even if it fails)
       assert_raises(ActiveProject::NotFoundError) do
         @adapter.find_project(created_board.id)
       end
    end
  end

  test "#delete_project raises NotFoundError for non-existent board" do
    skip "Skipping due to persistent VCR/API inconsistency for deleting non-existent board (301 vs 400)"
    non_existent_id = "invalidBoardId12345"
    VCR.use_cassette("trello_adapter/delete_project_not_found") do
      skip_if_missing_credentials # Need credentials to attempt delete
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_project(non_existent_id)
      end
    end
  end
end
