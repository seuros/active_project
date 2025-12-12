# frozen_string_literal: true

require_relative "fizzy_adapter_base_test"

class FizzyAdapterProjectTest < FizzyAdapterBaseTest
  # --- list_projects ---
  test "list_projects returns an array of projects" do
    VCR.use_cassette("fizzy/list_projects") do
      projects = @adapter.list_projects
      assert_kind_of Array, projects
      assert projects.any?, "Expected at least one project (board)"
      first_project = projects.first
      assert_kind_of ActiveProject::Resources::Project, first_project
      assert_not_nil first_project.id
      assert_not_nil first_project.name
      assert_equal :fizzy, first_project.adapter_source
    end
  end

  # --- find_project ---
  test "find_project returns a project for valid board_id" do
    VCR.use_cassette("fizzy/find_project") do
      project = @adapter.find_project(@board_id)
      assert_kind_of ActiveProject::Resources::Project, project
      assert_equal @board_id, project.id
      assert_not_nil project.name
      assert_equal :fizzy, project.adapter_source
    end
  end

  test "find_project raises NotFoundError for invalid board_id" do
    VCR.use_cassette("fizzy/find_project_not_found") do
      assert_raises ActiveProject::NotFoundError do
        @adapter.find_project("invalid_board_id_12345")
      end
    end
  end

  # --- create_project ---
  test "create_project creates a new board" do
    VCR.use_cassette("fizzy/create_project") do
      project = @adapter.create_project(name: "Test Board #{TIMESTAMP_PLACEHOLDER}")
      assert_kind_of ActiveProject::Resources::Project, project
      assert_not_nil project.id
      assert project.name.start_with?("Test Board")
      assert_equal :fizzy, project.adapter_source
    end
  end

  test "create_project raises ArgumentError without name" do
    assert_raises ArgumentError do
      @adapter.create_project({})
    end
  end

  # --- delete_project ---
  test "delete_project deletes a board" do
    VCR.use_cassette("fizzy/delete_project") do
      # First create a board to delete
      project = @adapter.create_project(name: "Board to Delete #{TIMESTAMP_PLACEHOLDER}")
      board_id = project.id

      # Then delete it
      result = @adapter.delete_project(board_id)
      assert_equal true, result
    end
  end
end
