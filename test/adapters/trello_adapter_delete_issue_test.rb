# frozen_string_literal: true

require_relative "trello_adapter_base_test"

class TrelloAdapterDeleteIssueTest < TrelloAdapterBaseTest
  # setup and teardown are inherited from TrelloAdapterBaseTest

  test "#delete_issue removes a card from Trello" do
    # Now delete the card
    VCR.use_cassette("trello_adapter/delete_issue") do
      # Execute the deletion
      result = @adapter.delete_issue(10000)

      # Check that deletion was successful
      assert result, "delete_issue should return true on success"

      # Verify card is no longer accessible
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.find_issue(10000)
      end
    end
  end

  test "#delete_issue raises NotFoundError for non-existent card" do
    non_existent_card_id = "non_existent_card_id_1700000000"

    VCR.use_cassette("trello_adapter/delete_issue_not_found") do
      assert_raises(ActiveProject::NotFoundError) do
        @adapter.delete_issue(non_existent_card_id)
      end
    end
  end
end
