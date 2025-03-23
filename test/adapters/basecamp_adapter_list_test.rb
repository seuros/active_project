# frozen_string_literal: true

require_relative "basecamp_adapter_base_test" # Inherit from base

class BasecampAdapterListTest < BasecampAdapterBaseTest
  # test "#create_list creates a new todolist in Basecamp" do
  #   skip_if_missing_credentials_or_ids(needs_project: true) # Need project ID
  #
  #   VCR.use_cassette("basecamp_adapter/create_list_success") do
  #     list_name = "Test Todolist via ActiveProject 1700000000"
  #     attributes = {
  #       name: list_name,
  #       description: "A test todolist created by the gem."
  #     }
  #
  #     # The method returns the raw hash of the created list
  #     created_list_data = @adapter.create_list(@project_id, attributes)
  #
  #     assert_instance_of Hash, created_list_data
  #     assert created_list_data["id"]
  #     assert_equal list_name, created_list_data["name"]
  #     assert_equal attributes[:description], created_list_data["description"]
  #     assert created_list_data["url"] # Check for a typical Basecamp response field
  #
  #     # Cleanup: Basecamp API allows archiving/trashing todolists.
  #     # Consider adding cleanup if necessary.
  #     # Example (requires implementing #delete_list or similar):
  #     # @adapter.delete_list(@project_id, created_list_data["id"]) if created_list_data&.dig("id")
  #   end
  # end

  test "#create_list raises ArgumentError with missing required attributes" do
    # No VCR needed
    attributes = {
      description: "List without a name"
      # Missing name
    }
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_list(@project_id, attributes) # Need a project_id even for ArgumentError check
    end
  end

  test "#create_list raises NotFoundError for non-existent project ID" do
    skip_if_missing_credentials_or_ids # Need credentials to make the call

    invalid_project_id = "000000" # Assuming 0 is not a valid ID
    VCR.use_cassette("basecamp_adapter/create_list_project_not_found") do
      attributes = { name: "Test List for Invalid Project" }
      # The error should be raised when trying to fetch the project to find the todoset
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.create_list(invalid_project_id, attributes)
      end
    end
  end
end
