# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Lists
        # Creates a new list on a Trello board.
        # @param board_id [String] The ID of the board.
        # @param attributes [Hash] List attributes. Required: :name. Optional: :pos.
        # @return [Hash] The raw data hash of the created list.
        def create_list(board_id, attributes)
          unless attributes[:name] && !attributes[:name].empty?
            raise ArgumentError, "Missing required attribute for Trello list creation: :name"
          end

          path = "boards/#{board_id}/lists"
          query_params = {
            name: attributes[:name],
            pos: attributes[:pos]
          }.compact

          make_request(:post, path, nil, query_params)
        end
      end
    end
  end
end
