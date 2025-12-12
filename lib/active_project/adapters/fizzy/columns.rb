# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Fizzy
      module Columns
        # Lists columns (workflow stages) on a board.
        # @param board_id [String] The board ULID.
        # @return [Array<Hash>] An array of column hashes.
        def list_lists(board_id)
          path = "boards/#{board_id}/columns.json"
          response = @connection.get(path)
          columns_data = parse_response(response)

          columns_data.map do |column_data|
            map_column_data(column_data, board_id)
          end
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Creates a new column on a board.
        # @param board_id [String] The board ULID.
        # @param attributes [Hash] Column attributes.
        #   - :name [String] Required. The column name.
        #   - :color [String] Optional. CSS var color (e.g., "var(--color-card-4)").
        # @return [Hash] The created column hash.
        def create_list(board_id, attributes)
          unless attributes[:name] && !attributes[:name].empty?
            raise ArgumentError, "Missing required attribute for Fizzy column creation: :name"
          end

          path = "boards/#{board_id}/columns.json"
          payload = {
            column: {
              name: attributes[:name],
              color: attributes[:color]
            }.compact
          }

          response = @connection.post(path) do |req|
            req.body = payload.to_json
          end

          # Extract column ID from Location header and fetch it
          location = response.headers["Location"]
          if location
            column_id = location.match(%r{/columns/([^/.]+)})[1]
            find_list(board_id, column_id)
          else
            # Fallback: parse response body if available
            column_data = parse_response(response)
            map_column_data(column_data, board_id)
          end
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Finds a specific column.
        # @param board_id [String] The board ULID.
        # @param column_id [String] The column ULID.
        # @return [Hash] The column hash.
        def find_list(board_id, column_id)
          path = "boards/#{board_id}/columns/#{column_id}.json"
          column_data = make_request(:get, path)
          return nil unless column_data

          map_column_data(column_data, board_id)
        end

        # Updates a column.
        # @param board_id [String] The board ULID.
        # @param column_id [String] The column ULID.
        # @param attributes [Hash] Attributes to update.
        #   - :name [String] The column name.
        #   - :color [String] CSS var color.
        # @return [Hash] The updated column hash.
        def update_list(board_id, column_id, attributes)
          path = "boards/#{board_id}/columns/#{column_id}.json"
          payload = {
            column: {
              name: attributes[:name],
              color: attributes[:color]
            }.compact
          }

          make_request(:put, path, payload.to_json)
          find_list(board_id, column_id)
        end

        # Deletes a column.
        # @param board_id [String] The board ULID.
        # @param column_id [String] The column ULID.
        # @return [Boolean] True if successfully deleted.
        def delete_list(board_id, column_id)
          path = "boards/#{board_id}/columns/#{column_id}.json"
          make_request(:delete, path)
          true
        end

        private

        def map_column_data(column_data, board_id)
          {
            id: column_data["id"],
            name: column_data["name"],
            color: column_data["color"],
            board_id: board_id,
            created_at: column_data["created_at"] ? Time.parse(column_data["created_at"]) : nil,
            raw_data: column_data
          }
        end
      end
    end
  end
end
