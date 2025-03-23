# frozen_string_literal: true

require "test_helper"
require_relative "trello_adapter_base_test"
# webmock/minitest is required in the base class

class TrelloAdapterCommentTest < TrelloAdapterBaseTest
  # setup and teardown are now inherited from TrelloAdapterBaseTest

  # --- Comment Tests ---

  test "#add_comment adds a comment to a card" do
    card_id_for_test = ENV.fetch("TRELLO_TEST_CARD_ID", "YOUR_CARD_ID_FOR_ADD_COMMENT")
    if card_id_for_test.include?("YOUR_CARD_ID")
      skip("Set TRELLO_TEST_CARD_ID environment variable to record VCR cassette for add_comment.")
    end

    VCR.use_cassette("trello_adapter/add_comment") do
      comment_text = "Test comment added at 1700000000"
      comment = @adapter.add_comment(card_id_for_test, comment_text)
      assert_instance_of ActiveProject::Resources::Comment, comment
      assert_equal comment_text, comment.body
      assert comment.id
      assert_equal :trello, comment.adapter_source
      assert_instance_of ActiveProject::Resources::User, comment.author if comment.author # Author might be nil depending on VCR
    end
  end
end
