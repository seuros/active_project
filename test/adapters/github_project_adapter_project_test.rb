# frozen_string_literal: true

require_relative "github_project_adapter_base_test"

class GithubProjectAdapterProjectTest < GithubProjectAdapterBaseTest
  test "#list_projects returns projects" do
    VCR.use_cassette("github_project/list_projects") do
      projects = @adapter.list_projects
      assert projects.any?
      assert_kind_of ActiveProject::Resources::Project, projects.first
      assert_equal :github, projects.first.adapter_source
    end
  end

  test "#find_project by number then by node-ID" do
    VCR.use_cassette("github_project/find_project_number") do
      proj = @adapter.find_project(TEST_GH_PROJECT_NUMBER)
      assert_equal TEST_GH_PROJECT_NUMBER.to_i, proj.key
      @node_id = proj.id
    end

    VCR.use_cassette("github_project/find_project_id") do
      proj2 = @adapter.find_project(@node_id)
      assert_equal @node_id, proj2.id
    end
  end

  test "create and delete project (happy-path)" do
    stamp   = Time.now.to_i
    project = nil

    VCR.use_cassette("github_project/create_project") do
      project = @adapter.create_project(name: "AP-Test-#{stamp}")
      assert project.id
    end

    VCR.use_cassette("github_project/delete_project") do
      assert @adapter.delete_project(project.id)
    end
  end
end
