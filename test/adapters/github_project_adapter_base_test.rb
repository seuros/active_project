# frozen_string_literal: true

require "test_helper"

class GithubProjectAdapterBaseTest < ActiveSupport::TestCase
  TEST_GH_OWNER          = ENV.fetch("GITHUB_PROJECT_OWNER", ENV.fetch("GITHUB_OWNER", ENV["USER"]))
  TEST_GH_PROJECT_NUMBER = ENV.fetch("GITHUB_PROJECT_NUMBER", "1")
  TEST_GH_ITEM_ID        = ENV["GITHUB_PROJECT_ITEM_ID"]

  def setup
    @token = ENV.fetch("GITHUB_PROJECT_ACCESS_TOKEN", "DUMMY_TOKEN")
    skip("Set GITHUB_PROJECT_ACCESS_TOKEN to enable GitHub-Project tests") if @token.start_with?("DUMMY")

    # Skip if using default environment user as owner (not a valid GitHub owner)
    skip("Set GITHUB_PROJECT_OWNER to a valid GitHub username") if TEST_GH_OWNER == ENV["USER"]

    @orig_cfg = ActiveProject.configuration.adapter_config(:github_project)&.options.dup || {}

    ActiveProject.configure do |c|
      c.add_adapter :github_project, owner: TEST_GH_OWNER, access_token: @token
    end
    @adapter = ActiveProject.adapter(:github_project)
    ActiveProject.reset_adapters
  end

  def teardown
    ActiveProject.configure do |c|
      if @orig_cfg.any?
        c.add_adapter :github_project, @orig_cfg
      else
        c.add_adapter :github_project, access_token: "DUMMY_TOKEN"
      end
    end
    ActiveProject.reset_adapters
  end
end
