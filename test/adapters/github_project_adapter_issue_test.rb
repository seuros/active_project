# frozen_string_literal: true

require_relative "github_project_adapter_base_test"

class GithubProjectAdapterIssueTest < GithubProjectAdapterBaseTest
  def project_id
    @project_id ||= @adapter.find_project(TEST_GH_PROJECT_NUMBER).id
  end

  test "#list_issues returns Issue objects" do
    VCR.use_cassette("github_project/list_issues") do
      issues = @adapter.list_issues(project_id)
      if issues.any?
        assert_kind_of ActiveProject::Resources::Issue, issues.first
        assert_equal :github, issues.first.adapter_source
      end
    end
  end

  test "draft issue create → title update" do
    # GitHub Project adapter doesn't support creating draft issues, only linking existing issues/PRs
    skip("GitHub Project adapter doesn't support draft issue creation - only linking existing content")

    new_issue = nil

    VCR.use_cassette("github_project/create_issue_draft") do
      new_issue = @adapter.create_issue(project_id,
                                        title: "Draft via AP #{Time.now.to_i}")
      assert new_issue.id
      assert new_issue.title.start_with?("(draft)")
    end

    VCR.use_cassette("github_project/update_issue_title") do
      updated = @adapter.update_issue(project_id, new_issue.id,
                                      title: "Updated #{Time.now.to_i}")
      assert_match(/Updated/, updated.title)
    end
  end
end
