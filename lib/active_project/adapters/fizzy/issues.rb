# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Fizzy
      module Issues
        # Lists cards within a specific board.
        # @param board_id [String] The ULID of the Fizzy board.
        # @param options [Hash] Optional options for filtering.
        #   - :tag_ids [Array<String>] Filter by tag IDs
        #   - :assignee_ids [Array<String>] Filter by assignee user IDs
        #   - :indexed_by [String] Filter: all, closed, not_now, stalled, postponing_soon, golden
        #   - :sorted_by [String] Sort: latest, newest, oldest
        # @return [Array<ActiveProject::Resources::Issue>] An array of issue resources.
        def list_issues(board_id, options = {})
          all_cards = []
          query = { "board_ids[]" => board_id }

          # Add optional filters
          options[:tag_ids]&.each { |id| query["tag_ids[]"] = id }
          options[:assignee_ids]&.each { |id| query["assignee_ids[]"] = id }
          query[:indexed_by] = options[:indexed_by] if options[:indexed_by]
          query[:sorted_by] = options[:sorted_by] if options[:sorted_by]

          path = "cards.json"

          loop do
            response = @connection.get(path, query)
            cards_data = parse_response(response)
            break if cards_data.empty?

            cards_data.each do |card_data|
              all_cards << map_card_data(card_data, board_id)
            end

            next_url = parse_next_link(response.headers["Link"])
            break unless next_url

            path = extract_path_from_url(next_url)
            query = {} # Query params are in the URL now
          end

          all_cards
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Finds a specific card by its number.
        # @param card_number [Integer, String] The card number (sequential per account).
        # @param context [Hash] Optional context (not required for Fizzy).
        # @return [ActiveProject::Resources::Issue] The issue resource.
        def find_issue(card_number, context = {})
          path = "cards/#{card_number}.json"
          card_data = make_request(:get, path)
          return nil unless card_data

          board_id = card_data.dig("board", "id")
          map_card_data(card_data, board_id)
        end

        # Creates a new card in a board.
        # @param board_id [String] The ULID of the Fizzy board.
        # @param attributes [Hash] Card attributes.
        #   - :title [String] Required. The card title.
        #   - :description [String] Optional. Rich text description (HTML).
        #   - :status [String] Optional. Initial status: published (default), drafted.
        #   - :tag_ids [Array<String>] Optional. Tag IDs to apply.
        # @return [ActiveProject::Resources::Issue] The created issue resource.
        def create_issue(board_id, attributes)
          title = attributes[:title]
          unless title && !title.empty?
            raise ArgumentError, "Missing required attribute for Fizzy card creation: :title"
          end

          path = "boards/#{board_id}/cards.json"
          payload = {
            card: {
              title: title,
              description: attributes[:description],
              status: attributes[:status] || "published",
              tag_ids: attributes[:tag_ids]
            }.compact
          }

          # Fizzy returns 201 Created with Location header
          response = @connection.post(path) do |req|
            req.body = payload.to_json
          end

          # Extract card number from Location header and fetch it
          location = response.headers["Location"]
          if location
            card_number = location.match(%r{/cards/(\d+)})[1]
            find_issue(card_number)
          else
            # Fallback: parse response body if available
            card_data = parse_response(response)
            map_card_data(card_data, board_id)
          end
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Updates an existing card.
        # @param card_number [Integer, String] The card number.
        # @param attributes [Hash] Attributes to update.
        #   - :title [String] The card title.
        #   - :description [String] Rich text description.
        #   - :status [Symbol] Status change: :open, :closed, :on_hold.
        #   - :tag_ids [Array<String>] Tag IDs to apply.
        # @param context [Hash] Optional context (not required for Fizzy).
        # @return [ActiveProject::Resources::Issue] The updated issue resource.
        def update_issue(card_number, attributes, context = {})
          put_payload = {}
          put_payload[:title] = attributes[:title] if attributes.key?(:title)
          put_payload[:description] = attributes[:description] if attributes.key?(:description)
          put_payload[:tag_ids] = attributes[:tag_ids] if attributes.key?(:tag_ids)

          status_change_required = attributes.key?(:status)
          target_status = attributes[:status] if status_change_required

          unless !put_payload.empty? || status_change_required
            raise ArgumentError, "No attributes provided to update for FizzyAdapter#update_issue"
          end

          # Update basic fields via PUT
          unless put_payload.empty?
            put_path = "cards/#{card_number}.json"
            make_request(:put, put_path, { card: put_payload }.to_json)
          end

          # Handle status changes via separate endpoints
          if status_change_required
            handle_status_change(card_number, target_status)
          end

          find_issue(card_number, context)
        end

        # Deletes a card.
        # @param card_number [Integer, String] The card number to delete.
        # @param context [Hash] Optional context (not required for Fizzy).
        # @return [Boolean] True if successfully deleted.
        def delete_issue(card_number, context = {})
          path = "cards/#{card_number}.json"
          make_request(:delete, path)
          true
        end

        private

        def handle_status_change(card_number, target_status)
          case target_status
          when :closed
            # POST /cards/:num/closure
            make_request(:post, "cards/#{card_number}/closure.json")
          when :open
            # DELETE /cards/:num/closure (reopen)
            begin
              make_request(:delete, "cards/#{card_number}/closure.json")
            rescue NotFoundError
              # Card wasn't closed, ignore
            end
          when :on_hold
            # POST /cards/:num/not_now
            make_request(:post, "cards/#{card_number}/not_now.json")
          end
        end

        def map_card_data(card_data, board_id)
          # Determine status based on card state and column
          status = determine_card_status(card_data, board_id)

          # Map creator
          creator = map_user_data(card_data["creator"])

          # Map assignees if present (Fizzy cards can have multiple assignees)
          assignees = (card_data["assignees"] || []).map { |a| map_user_data(a) }.compact

          Resources::Issue.new(
            self,
            id: card_data["id"],
            key: card_data["number"]&.to_s,
            title: card_data["title"],
            description: card_data["description"],
            status: status,
            assignees: assignees,
            reporter: creator,
            project_id: board_id || card_data.dig("board", "id"),
            created_at: card_data["created_at"] ? Time.parse(card_data["created_at"]) : nil,
            updated_at: card_data["last_active_at"] ? Time.parse(card_data["last_active_at"]) : nil,
            due_on: nil, # Fizzy doesn't have due dates on cards
            priority: nil,
            adapter_source: :fizzy,
            raw_data: card_data
          )
        end

        def determine_card_status(card_data, board_id)
          # Check for closed status
          return :closed if card_data["closed"] == true

          # Check for not_now status
          return :on_hold if card_data["not_now"].present?

          # Check column-based status mapping from config
          column_name = card_data.dig("column", "name")
          if column_name && board_id
            board_mappings = @config.status_mappings[board_id]
            if board_mappings && board_mappings.key?(column_name)
              return board_mappings[column_name]
            end
          end

          # Default: published cards are open
          card_data["status"] == "drafted" ? :open : :open
        end
      end
    end
  end
end
