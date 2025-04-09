# frozen_string_literal: true

require_relative "basecamp_adapter_base_test" # Inherit from base

class BasecampAdapterErrorTest < BasecampAdapterBaseTest
  # --- ArgumentError Tests (Don't require API calls) ---

  test "#find_issue requires project_id context" do
    assert_raises(ArgumentError) { @adapter.find_issue(123) } # No context
    assert_raises(ArgumentError) { @adapter.find_issue(123, {}) } # Empty context
  end

  test "#update_issue requires project_id context" do
    assert_raises(ArgumentError) { @adapter.update_issue(123, { title: "new" }) }
    assert_raises(ArgumentError) { @adapter.update_issue(123, { title: "new" }, {}) }
  end

   test "#add_comment requires project_id context" do
    assert_raises(ArgumentError) { @adapter.add_comment(123, "test comment") }
    assert_raises(ArgumentError) { @adapter.add_comment(123, "test comment", {}) }
  end

  # --- Error Handling Tests ---

  test "#find_project raises NotFoundError for non-existent project ID (error handling section)" do
     VCR.use_cassette("basecamp_adapter/find_project_not_found_error_section") do
       assert_raises(ActiveProject::NotFoundError) do
         @adapter.find_project("000000") # Assuming 0 is not a valid ID
       end
     end
   end

   test "adapter raises AuthenticationError with invalid credentials" do
     # Need real account ID for this test to work correctly during recording
     skip if @account_id.include?("DUMMY")

    # Configure with bad credentials specifically for this test
    ActiveProject.configure do |config|
      config.add_adapter :basecamp, account_id: @account_id, access_token: "invalid-token"
    end
    bad_adapter = ActiveProject.adapter(:basecamp) # Get the adapter with bad config

     VCR.use_cassette("basecamp_adapter/authentication_error") do
       assert_raises(ActiveProject::AuthenticationError) do
         bad_adapter.list_projects # Any method requiring authentication
       end
     end
   end
end
