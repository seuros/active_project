# frozen_string_literal: true

require_relative "github_project_adapter_base_test"

class GithubProjectAdapterCommentTest < GithubProjectAdapterBaseTest
  #
  # We grab the first real Issue already attached to the project
  # and run the full comment life-cycle on it. This avoids the old
  # TEST_GH_ITEM_ID env-var dance and guarantees we’re never
  # targeting a DraftIssue.
  #
  def project_id
    @project_id ||= @adapter.find_project(TEST_GH_PROJECT_NUMBER).id
  end

  def first_issue_item_id
    @first_issue_item_id ||= begin
      issues = @adapter.list_issues(project_id)
      skip("Project has no attached Issues to comment on") if issues.empty?
      issues.first.id
    end
  end

  test "add → update → delete comment on a project Issue item" do
    comment = nil

    VCR.use_cassette("github_project/comment_lifecycle") do
      # -- add ---------------------------------------------------------------
      comment = @adapter.add_comment(first_issue_item_id,
                                     "Auto-comment #{Time.now.to_i}")
      assert_kind_of ActiveProject::Resources::Comment, comment

      # -- update ------------------------------------------------------------
      comment = @adapter.update_comment(comment.id,
                                        "Edited #{Time.now.to_i}")
      assert_match(/Edited/, comment.body)

      # -- delete ------------------------------------------------------------
      assert @adapter.delete_comment(comment.id)
    end
  end
end
