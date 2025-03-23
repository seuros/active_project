# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

# Separate tests for Basecamp todolist creation
class BasecampCreateListTest < BasecampAdapterBaseTest
  # test "#create_list creates a new todolist" do
  #   skip "Record"
  #   skip_if_missing_credentials_or_ids(needs_project: true)
  #
  #   VCR.use_cassette("basecamp_adapter/create_list") do
  #     puts "Creating a new todolist for project ID: #{@project_id}"
  #     timestamp = 1700000000
  #     attributes = {
  #       name: "Test Todolist #{timestamp}",
  #       description: "Test todolist created by ActiveProject gem."
  #     }
  #
  #     # create_list returns the raw hash from the API
  #     list_data = @adapter.create_list(@project_id, attributes)
  #
  #     assert_instance_of Hash, list_data
  #     assert list_data["id"]
  #     assert_equal attributes[:name], list_data["name"]
  #     # Note: Deleting the created list might be necessary for test cleanup
  #   end
  # end

  test "#create_list raises ArgumentError if name is missing" do
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_list(@project_id, { description: "No name" })
    end
  end

  test "#create_list raises NotFoundError if project is invalid" do
     skip_if_missing_credentials_or_ids # Need credentials to make the call
     invalid_project_id = "000000"
     VCR.use_cassette("basecamp_adapter/create_list_invalid_project") do
        assert_raises(ActiveProject::NotFoundError) do
          @adapter.create_list(invalid_project_id, { name: "Test List" })
        end
     end
  end
end
