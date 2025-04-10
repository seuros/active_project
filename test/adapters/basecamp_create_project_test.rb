# frozen_string_literal: true

require_relative "basecamp_adapter_base_test"

# Separate tests for Basecamp project creation
class BasecampCreateProjectTest < BasecampAdapterBaseTest
  test "#create_project creates a new project" do
    VCR.use_cassette("basecamp_adapter/create_project") do
      timestamp = 1_700_000_000
      attributes = {
        name: "Test Project #{timestamp}",
        description: "Test project created by ActiveProject gem."
      }

      project = @adapter.create_project(attributes)

      assert_instance_of ActiveProject::Resources::Project, project
      assert_equal :basecamp, project.adapter_source
      assert project.id
      assert_equal attributes[:name], project.name
      assert_nil project.key
      # NOTE: Deleting the created project might be necessary for test cleanup
    end
  end

  test "#create_project raises ArgumentError if name is missing" do
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_project(description: "No name")
    end
  end
end
