# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Fizzy
      module Projects
        # Lists boards accessible by the configured credentials.
        # Handles pagination automatically using the Link header.
        # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
        def list_projects
          all_boards = []
          path = "boards.json"

          loop do
            response = @connection.get(path)
            boards_data = parse_response(response)
            break if boards_data.empty?

            boards_data.each do |board_data|
              all_boards << map_board_data(board_data)
            end

            next_url = parse_next_link(response.headers["Link"])
            break unless next_url

            path = extract_path_from_url(next_url)
          end

          all_boards
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Finds a specific board by its ID.
        # @param board_id [String] The ULID of the Fizzy board.
        # @return [ActiveProject::Resources::Project] The project resource.
        def find_project(board_id)
          path = "boards/#{board_id}.json"
          board_data = make_request(:get, path)
          return nil unless board_data

          map_board_data(board_data)
        end

        # Creates a new board in Fizzy.
        # @param attributes [Hash] Board attributes. Required: :name. Optional: :all_access, :auto_postpone_period.
        # @return [ActiveProject::Resources::Project] The created project resource.
        def create_project(attributes)
          unless attributes[:name] && !attributes[:name].empty?
            raise ArgumentError, "Missing required attribute for Fizzy board creation: :name"
          end

          path = "boards.json"
          payload = {
            board: {
              name: attributes[:name],
              all_access: attributes.fetch(:all_access, true),
              auto_postpone_period: attributes[:auto_postpone_period]
            }.compact
          }

          # Fizzy returns 201 Created with Location header, need to fetch the board
          response = @connection.post(path) do |req|
            req.body = payload.to_json
          end

          # Extract board ID from Location header and fetch it
          location = response.headers["Location"]
          if location
            board_id = location.match(%r{/boards/([^/.]+)})[1]
            find_project(board_id)
          else
            # Fallback: parse response body if available
            board_data = parse_response(response)
            map_board_data(board_data)
          end
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Deletes a board in Fizzy.
        # @param board_id [String] The ULID of the board to delete.
        # @return [Boolean] true if deletion was successful (API returns 204).
        def delete_project(board_id)
          path = "boards/#{board_id}.json"
          make_request(:delete, path)
          true
        end

        private

        def map_board_data(board_data)
          Resources::Project.new(
            self,
            id: board_data["id"],
            key: nil,
            name: board_data["name"],
            adapter_source: :fizzy,
            raw_data: board_data
          )
        end
      end
    end
  end
end
