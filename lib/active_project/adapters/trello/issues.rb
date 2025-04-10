# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Issues
        DEFAULT_FIELDS = %w[id name desc closed idList idBoard due dueComplete idMembers].freeze

        # Lists Trello cards on a specific board.
        # @param board_id [String] The ID of the Trello board.
        # @param options [Hash] Optional filtering options. Accepts :filter and :fields.
        # @return [Array<ActiveProject::Resources::Issue>]
        def list_issues(board_id, options = {})
          path = "boards/#{board_id}/cards"

          fields = options[:fields] ? Array(options[:fields]).join(",") : DEFAULT_FIELDS.join(",")
          query = { fields: fields, list: true }
          query[:filter] = options[:filter] if options[:filter]

          cards_data = make_request(:get, path, nil, query)
          return [] unless cards_data.is_a?(Array)

          cards_data.map { |card_data| map_card_data(card_data, board_id) }
        end

        # Finds a specific Card by its ID.
        # @param card_id [String] The ID of the Trello Card.
        # @param context [Hash] Optional context. Accepts :fields for specific field selection.
        # @return [ActiveProject::Resources::Issue]
        def find_issue(card_id, context = {})
          path = "cards/#{card_id}"

          fields = context[:fields] ? Array(context[:fields]).join(",") : DEFAULT_FIELDS.join(",")
          query = { fields: fields, list: true }

          card_data = make_request(:get, path, nil, query)
          map_card_data(card_data, card_data["idBoard"])
        end

        # Creates a new Card in Trello.
        # @param _board_id [String] Ignored (context).
        # @param attributes [Hash] Card attributes. Required: :list_id, :title. Optional: :description, :assignee_ids, :due_on.
        # @return [ActiveProject::Resources::Issue]
        def create_issue(_board_id, attributes)
          list_id = attributes[:list_id]
          title = attributes[:title]

          unless list_id && title && !title.empty?
            raise ArgumentError, "Missing required attributes for Trello card creation: :list_id, :title"
          end

          path = "cards"
          query_params = {
            idList: list_id,
            name: title,
            desc: attributes[:description],
            idMembers: attributes[:assignee_ids]&.join(","),
            due: attributes[:due_on]&.iso8601
          }.compact

          card_data = make_request(:post, path, nil, query_params)
          map_card_data(card_data, card_data["idBoard"])
        end

        # Updates an existing Card in Trello.
        # @param card_id [String] The ID of the Trello Card.
        # @param attributes [Hash] Attributes to update (e.g., :title, :description, :list_id, :closed, :due_on, :assignee_ids, :status).
        # @param context [Hash] Optional context. Accepts :fields for return data field selection.
        # @return [ActiveProject::Resources::Issue]
        def update_issue(card_id, attributes, context = {})
          update_attributes = attributes.dup

          if update_attributes.key?(:status)
            target_status = update_attributes.delete(:status)

            board_id = update_attributes[:board_id] || begin
                                                         find_issue(card_id).project_id
                                                       rescue NotFoundError
                                                         raise NotFoundError, "Trello card with ID '#{card_id}' not found."
                                                       end

            unless board_id
              raise ApiError, "Could not determine board ID for card '#{card_id}' to perform status mapping."
            end

            board_mappings = @config.status_mappings[board_id]
            unless board_mappings
              raise ConfigurationError,
                    "Trello status mapping not configured for board ID '#{board_id}'. Cannot map status ':#{target_status}'."
            end

            target_list_id = board_mappings.key(target_status)

            unless target_list_id
              raise ConfigurationError,
                    "Target status ':#{target_status}' not found in configured Trello status mappings for board ID '#{board_id}'."
            end

            update_attributes[:list_id] = target_list_id
          end

          path = "cards/#{card_id}"

          query_params = {}
          query_params[:name] = update_attributes[:title] if update_attributes.key?(:title)
          query_params[:desc] = update_attributes[:description] if update_attributes.key?(:description)
          query_params[:closed] = update_attributes[:closed] if update_attributes.key?(:closed)
          query_params[:idList] = update_attributes[:list_id] if update_attributes.key?(:list_id)
          query_params[:due] = update_attributes[:due_on]&.iso8601 if update_attributes.key?(:due_on)
          query_params[:dueComplete] = update_attributes[:dueComplete] if update_attributes.key?(:dueComplete)
          if update_attributes.key?(:assignee_ids)
            query_params[:idMembers] =
              update_attributes[:assignee_ids]&.join(",")
          end

          return find_issue(card_id, context) if query_params.empty?

          card_data = make_request(:put, path, nil, query_params.compact)
          map_card_data(card_data, card_data["idBoard"])
        end

        # Deletes a Trello card.
        # @param card_id [String] The ID of the Trello Card to delete.
        # @return [Boolean] True if successfully deleted.
        def delete_issue(card_id, **)
          path = "cards/#{card_id}"
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
