# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Comments
        # Adds a comment to a Card in Trello.
        # @param card_id [String] The ID of the Trello Card.
        # @param comment_body [String] The comment text (Markdown).
        # @param context [Hash] Optional context (ignored).
        # @return [ActiveProject::Resources::Comment] The created comment resource.
        def add_comment(card_id, comment_body, _context = {})
          path = "cards/#{card_id}/actions/comments"
          query_params = { text: comment_body }
          comment_data = make_request(:post, path, nil, query_params)
          map_comment_action_data(comment_data, card_id)
        end

        # Updates a comment on a Card in Trello.
        # @param comment_id [String] The ID of the comment action.
        # @param body [String] The new comment text (Markdown).
        # @param context [Hash] Required context: { card_id: '...' }.
        # @return [ActiveProject::Resources::Comment] The updated comment resource.
        def update_comment(comment_id, body, context = {})
          card_id = context[:card_id]
          unless card_id
            raise ArgumentError,
                  "Missing required context: :card_id must be provided for TrelloAdapter#update_comment"
          end

          path = "cards/#{card_id}/actions/#{comment_id}/comments"
          query_params = { text: body }
          comment_data = make_request(:put, path, nil, query_params)
          map_comment_action_data(comment_data, card_id)
        end

        # Deletes a comment from a Card in Trello.
        # @param comment_id [String] The ID of the comment action to delete.
        # @param context [Hash] Required context: { card_id: '...' }.
        # @return [Boolean] True if successfully deleted.
        def delete_comment(comment_id, context = {})
          card_id = context[:card_id]
          unless card_id
            raise ArgumentError,
                  "Missing required context: :card_id must be provided for TrelloAdapter#delete_comment"
          end

          path = "cards/#{card_id}/actions/#{comment_id}/comments"
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
