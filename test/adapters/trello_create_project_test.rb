# frozen_string_literal: true

require "test_helper"

# Separate tests for Trello board creation
class TrelloCreateProjectTest < ActiveSupport::TestCase
  def setup
    @api_key = ENV.fetch("TRELLO_API_KEY", "DUMMY_TRELLO_KEY")
    @api_token = ENV.fetch("TRELLO_API_TOKEN", "DUMMY_TRELLO_TOKEN")

    # Store original config options for restoration
    @original_trello_config_options = ActiveProject.configuration.adapter_config(:trello)&.options&.dup || {}


    ActiveProject.configure do |config|
      config.add_adapter :trello, api_key: @api_key, api_token: @api_token do |trello_config|
        trello_config.status_mappings = {} # Default empty mappings
      end
    end

    # Initialize adapter using the new config structure via the helper
    @adapter = ActiveProject.adapter(:trello)
    # Clear memoized adapter instance
    ActiveProject.reset_adapters
  end

  def teardown
    # Restore original config options after each test
    ActiveProject.configure do |config|
      if @original_trello_config_options.any?
         original_mappings = @original_trello_config_options.delete(:status_mappings)
         if original_mappings
           config.add_adapter :trello, @original_trello_config_options do |trello_config|
             trello_config.status_mappings = original_mappings
           end
         else
           config.add_adapter :trello, @original_trello_config_options
         end
      else
         config.add_adapter :trello, {}
      end
    end
    # Clear memoized adapter instance again after teardown
    ActiveProject.reset_adapters
  end

  # Skips the test if dummy credentials are detected
  def skip_if_missing_credentials
    if @api_key.include?("DUMMY") || @api_token.include?("DUMMY")
      skip("Set TRELLO_API_KEY and TRELLO_API_TOKEN environment variables with write permissions.")
    end
  end

  test "#create_project creates a new board" do
    skip_if_missing_credentials # Also ensure token has write permissions for recording

    skip "Skipping due to Trello 'Workspaces are full' error (account limit)"
    VCR.use_cassette("trello_adapter/create_project") do
      timestamp = 1700000000
      attributes = {
        name: "Test Board #{timestamp}",
        description: "Test board created by ActiveProject gem.",
        default_lists: false # Avoid creating default lists for cleaner test
      }

      project = @adapter.create_project(attributes)

      assert_instance_of ActiveProject::Resources::Project, project # Check resource type
      assert_equal :trello, project.adapter_source
      assert project.id
      assert_equal attributes[:name], project.name
      assert_nil project.key
      # Note: Deleting the created board might be necessary for test cleanup
      # Trello API allows deleting boards: DELETE /boards/{id}
    end
  end

  test "#create_project raises ArgumentError if name is missing" do
    assert_raises(ArgumentError, /Missing required attribute.*:name/) do
      @adapter.create_project(description: "No name")
    end
  end
end
