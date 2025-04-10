# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Projects
        # Lists Trello boards accessible by the configured token.
        # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
        def list_projects
          path = "members/me/boards"
          query = { fields: "id,name,desc" }
          boards_data = make_request(:get, path, nil, query)

          return [] unless boards_data.is_a?(Array)

          boards_data.map do |board_data|
            Resources::Project.new(self,
                                   id: board_data["id"],
                                   key: nil,
                                   name: board_data["name"],
                                   adapter_source: :trello,
                                   raw_data: board_data)
          end
        end

        # Finds a specific Trello Board by its ID.
        # @param board_id [String] The ID of the Trello Board.
        # @return [ActiveProject::Resources::Project]
        def find_project(board_id)
          path = "boards/#{board_id}"
          query = { fields: "id,name,desc" }
          board_data = make_request(:get, path, nil, query)

          Resources::Project.new(self,
                                 id: board_data["id"],
                                 key: nil,
                                 name: board_data["name"],
                                 adapter_source: :trello,
                                 raw_data: board_data)
        end

        # Creates a new board in Trello.
        # @param attributes [Hash] Board attributes. Required: :name. Optional: :description, :default_lists.
        # @return [ActiveProject::Resources::Project]
        def create_project(attributes)
          unless attributes[:name] && !attributes[:name].empty?
            raise ArgumentError, "Missing required attribute for Trello board creation: :name"
          end

          path = "boards/"
          query_params = {
            name: attributes[:name],
            desc: attributes[:description],
            defaultLists: attributes.fetch(:default_lists, true)
          }.compact

          board_data = make_request(:post, path, nil, query_params)

          Resources::Project.new(self,
                                 id: board_data["id"],
                                 key: nil,
                                 name: board_data["name"],
                                 adapter_source: :trello,
                                 raw_data: board_data)
        end

        # Deletes a board in Trello.
        # WARNING: This is a permanent deletion.
        # @param board_id [String] The ID of the board to delete.
        # @return [Boolean] true if deletion was successful (API returns 200).
        # @raise [NotFoundError] if the board is not found.
        # @raise [AuthenticationError] if credentials lack permission.
        # @raise [ApiError] for other errors.
        def delete_project(board_id)
          path = "/boards/#{board_id}"
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
