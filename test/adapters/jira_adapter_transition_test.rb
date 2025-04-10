# frozen_string_literal: true

require_relative "jira_adapter_base_test"

# Tests for Jira Adapter Transition operations using static data.
class JiraAdapterTransitionTest < JiraAdapterBaseTest
  test "#transition_issue successfully transitions an issue" do
    skip "Skipping transition test; target status 'Done' not available for static issue LAC-10."
    issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use constant

    # IMPORTANT: Requires a valid target status name/ID for the LAC-10 issue's workflow
    # You might need to adjust this ENV variable or the hardcoded value based on LAC-10's actual workflow.
    target_status = ENV.fetch("JIRA_TEST_TARGET_STATUS", "Done") # Example target status

    VCR.use_cassette("jira_adapter/transition_issue_success_static") do # New cassette name
      # Assuming the transition is possible from the issue's current state
      result = @adapter.transition_issue(issue_key_for_test, target_status)
      assert result, "Transition should return true on success"
      # Optional verification: Fetch issue again and check status
      # issue_after = @adapter.find_issue(issue_key_for_test)
      # assert_equal :closed, issue_after.status # Assuming 'Done' maps to :closed
    end
  end

  test "#transition_issue successfully transitions an issue with resolution and comment" do
    skip "Skipping transition with options test; requires specific workflow state/permissions for LAC-10."

    # issue_key_for_test = TEST_JIRA_ISSUE_KEY
    # target_status = ENV.fetch("JIRA_TEST_TARGET_STATUS", "Done")
    # resolution_name = ENV.fetch("JIRA_TEST_RESOLUTION_NAME", "Done")
    #
    # VCR.use_cassette("jira_adapter/transition_issue_with_options_static") do
    #   comment_text = "Transitioning with comment static test #{Time.now.to_i}"
    #   options = {
    #     comment: comment_text,
    #     resolution: { name: resolution_name }
    #   }
    #   result = @adapter.transition_issue(issue_key_for_test, target_status, options)
    #   assert result, "Transition with options should return true on success"
    #   # Optional: Verify comment and resolution on the issue
    # end
  end

  test "#transition_issue raises NotFoundError for invalid issue key" do
    invalid_issue_key = "NONEXISTENT-789"
    target_status = "Done"

    VCR.use_cassette("jira_adapter/transition_issue_invalid_issue_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError, /Jira issue '#{invalid_issue_key}' not found/) do
        @adapter.transition_issue(invalid_issue_key, target_status)
      end
    end
  end

  test "#transition_issue raises NotFoundError for invalid target status ID" do
    issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use constant
    invalid_target_status_id = "99999"

    VCR.use_cassette("jira_adapter/transition_issue_invalid_target_id_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError,
                    /Target transition '#{invalid_target_status_id}' not found or available/) do
        @adapter.transition_issue(issue_key_for_test, invalid_target_status_id)
      end
    end
  end

  test "#transition_issue raises NotFoundError for invalid target status" do
    issue_key_for_test = TEST_JIRA_ISSUE_KEY # Use constant
    invalid_target_status = "NonExistentStatus123"

    VCR.use_cassette("jira_adapter/transition_issue_invalid_target_static") do # New cassette name
      assert_raises(ActiveProject::NotFoundError,
                    /Target transition '#{invalid_target_status}' not found or available/) do
        @adapter.transition_issue(issue_key_for_test, invalid_target_status)
      end
    end
  end
end
