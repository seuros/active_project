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
      end
    end
  end
end
