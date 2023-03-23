# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "time"
require "openssl" # For webhook signature
require "base64"  # For webhook signature

module ActiveProject
  module Adapters
    # Adapter for interacting with the Trello REST API.
    # Implements the interface defined in ActiveProject::Adapters::Base.
    # API Docs: https://developer.atlassian.com/cloud/trello/rest/
    class TrelloAdapter < Base
      BASE_URL = "https://api.trello.com/1/"

      # Computes the expected Trello webhook signature.
      # @param callback_url [String] The exact URL registered for the webhook.
      # @param response_body [String] The raw response body received from Trello.
      # @param api_secret [String] The Trello API Secret (OAuth Secret or Application Secret).
      # @return [String] The Base64 encoded HMAC-SHA1 signature.
      def self.compute_webhook_signature(callback_url, response_body, api_secret)
        digest = OpenSSL::Digest.new("sha1")
        hmac = OpenSSL::HMAC.digest(digest, api_secret, response_body + callback_url)
        Base64.strict_encode64(hmac)
      end

      attr_reader :config

      # Initializes the Trello Adapter.
      # @param config [Configurations::TrelloConfiguration] The configuration object for Trello.
      # @raise [ArgumentError] if required configuration options (:api_key, :api_token) are missing.
      def initialize(config:)
        unless config.is_a?(ActiveProject::Configurations::TrelloConfiguration)
          raise ArgumentError, "TrelloAdapter requires a TrelloConfiguration object"
        end
        @config = config

        unless @config.api_key && !@config.api_key.empty? && @config.api_token && !@config.api_token.empty?
          raise ArgumentError, "TrelloAdapter configuration requires :api_key and :api_token"
        end

        @connection = initialize_connection
      end


      # --- Resource Factories ---

      # Returns a factory for Project resources.
      # @return [ResourceFactory<Resources::Project>]
      def projects
        ResourceFactory.new(adapter: self, resource_class: Resources::Project)
      end

      # Returns a factory for Issue resources (Cards).
      # @return [ResourceFactory<Resources::Issue>]
      def issues
        ResourceFactory.new(adapter: self, resource_class: Resources::Issue)
      end

      # --- Implementation of Base methods ---

      # Lists Trello boards accessible by the configured token.
      # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
      def list_projects
        path = "members/me/boards"
        query = { fields: "id,name,desc" }
        boards_data = make_request(:get, path, nil, query)

        return [] unless boards_data.is_a?(Array)

        boards_data.map do |board_data|
          Resources::Project.new(self, # Pass adapter instance
            id: board_data["id"],
            key: nil,
            name: board_data["name"],
            adapter_source: :trello,
            raw_data: board_data
          )
        end
      end

      # Finds a specific Trello Board by its ID.
      # @param board_id [String] The ID of the Trello Board.
      # @return [ActiveProject::Resources::Project] The project resource.
      def find_project(board_id)
         path = "boards/#{board_id}"
         query = { fields: "id,name,desc" }
         board_data = make_request(:get, path, nil, query)

         Resources::Project.new(self, # Pass adapter instance
           id: board_data["id"],
           key: nil,
           name: board_data["name"],
           adapter_source: :trello,
           raw_data: board_data
         )
      end

      # Creates a new board in Trello.
      # @param attributes [Hash] Board attributes. Required: :name. Optional: :description, :default_lists.
      # @return [ActiveProject::Resources::Project] The created project resource.
      def create_project(attributes)
        unless attributes[:name] && !attributes[:name].empty?
          raise ArgumentError, "Missing required attribute for Trello board creation: :name"
        end

        path = "boards/"
        query_params = {
          name: attributes[:name],
          desc: attributes[:description],
          defaultLists: attributes.fetch(:default_lists, true) # Default to creating lists
          # Add other board options here if needed (e.g., idOrganization)
        }.compact

        board_data = make_request(:post, path, nil, query_params)

        Resources::Project.new(self, # Pass adapter instance
          id: board_data["id"],
          key: nil,
          name: board_data["name"],
          adapter_source: :trello,
          raw_data: board_data
        )
      end

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

      # Deletes a board in Trello.
      # WARNING: This is a permanent deletion.
      # @param board_id [String] The ID of the board to delete.
      # @return [Boolean] true if deletion was successful (API returns 200).
      # @raise [NotFoundError] if the board is not found.
      # @raise [AuthenticationError] if credentials lack permission.
      # @raise [ApiError] for other errors.
      def delete_project(board_id)
        path = "/boards/#{board_id}"
        make_request(:delete, path) # DELETE returns 200 OK on success
        true # Return true if make_request doesn't raise an error
      end




      # Lists Trello cards on a specific board.
      # @param board_id [String] The ID of the Trello board.
      # @param options [Hash] Optional filtering options.
      # @return [Array<ActiveProject::Resources::Issue>] An array of issue resources.
      def list_issues(board_id, options = {})
        path = "boards/#{board_id}/cards"
        # Fetch idMembers and list name for potential name mapping fallback
        query = { fields: "id,name,desc,closed,idList,idBoard,due,dueComplete,idMembers", list: true }
        query[:filter] = options[:filter] if options[:filter]

        cards_data = make_request(:get, path, nil, query)
        return [] unless cards_data.is_a?(Array)

        cards_data.map { |card_data| map_card_data(card_data, board_id) }
      end

      # Finds a specific Card by its ID.
      # @param card_id [String] The ID of the Trello Card.
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Issue] The issue resource.
      def find_issue(card_id, context = {})
        path = "cards/#{card_id}"
        # Fetch idMembers and list name for potential name mapping fallback
        query = { fields: "id,name,desc,closed,idList,idBoard,due,dueComplete,idMembers", list: true }
        card_data = make_request(:get, path, nil, query)
        map_card_data(card_data, card_data["idBoard"])
      end

      # Creates a new Card in Trello.
      # @param _board_id [String] Ignored (context).
      # @param attributes [Hash] Card attributes. Required: :list_id, :title. Optional: :description, :assignee_ids, :due_on.
      # @return [ActiveProject::Resources::Issue] The created issue resource.
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
          # Use assignee_ids (expects an array of Trello member IDs)
          idMembers: attributes[:assignee_ids]&.join(","),
          due: attributes[:due_on]&.iso8601
        }.compact

        card_data = make_request(:post, path, nil, query_params)
        map_card_data(card_data, card_data["idBoard"])
      end

      # Updates an existing Card in Trello.
      # @param card_id [String] The ID of the Trello Card.
      # @param attributes [Hash] Attributes to update (e.g., :title, :description, :list_id, :closed, :due_on, :assignee_ids, :status).
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Issue] The updated issue resource.
      def update_issue(card_id, attributes, context = {})
        # Make a mutable copy of attributes
        update_attributes = attributes.dup

        # Handle :status mapping to :list_id
        if update_attributes.key?(:status)
          target_status = update_attributes.delete(:status) # Remove status key

          # Fetch board_id efficiently if not already known
          # We need the board_id to look up the correct status mapping
          board_id = update_attributes[:board_id] || begin
            find_issue(card_id).project_id # Fetch the issue to get its board_id
          rescue NotFoundError
            # Re-raise NotFoundError if the card itself doesn't exist
            raise NotFoundError, "Trello card with ID '#{card_id}' not found."
          end

          unless board_id
            # This should theoretically not happen if find_issue succeeded or board_id was passed
            raise ApiError, "Could not determine board ID for card '#{card_id}' to perform status mapping."
          end

          # Use stored config for status mappings
          board_mappings = @config.status_mappings[board_id]
          unless board_mappings
            raise ConfigurationError, "Trello status mapping not configured for board ID '#{board_id}'. Cannot map status ':#{target_status}'."
          end

          # Find the target list ID by looking up the status symbol in the board's mappings.
          # We iterate through the mappings hash { list_id => status_symbol }
          target_list_id = board_mappings.key(target_status)

          unless target_list_id
            raise ConfigurationError, "Target status ':#{target_status}' not found in configured Trello status mappings for board ID '#{board_id}'."
          end

          # Add the resolved list_id to the attributes to be updated
          update_attributes[:list_id] = target_list_id
        end


        path = "cards/#{card_id}"

        # Build query parameters from the potentially modified update_attributes
        query_params = {}
        query_params[:name] = update_attributes[:title] if update_attributes.key?(:title)
        query_params[:desc] = update_attributes[:description] if update_attributes.key?(:description)
        query_params[:closed] = update_attributes[:closed] if update_attributes.key?(:closed)
        query_params[:idList] = update_attributes[:list_id] if update_attributes.key?(:list_id) # Use the mapped list_id if status was provided
        query_params[:due] = update_attributes[:due_on]&.iso8601 if update_attributes.key?(:due_on)
        query_params[:dueComplete] = update_attributes[:dueComplete] if update_attributes.key?(:dueComplete)
        # Use assignee_ids (expects an array of Trello member IDs)
        query_params[:idMembers] = update_attributes[:assignee_ids]&.join(",") if update_attributes.key?(:assignee_ids)

        # If after processing :status, there are no actual changes, just return the current issue state
        return find_issue(card_id, context) if query_params.empty?

        # Make the PUT request to update the card
        card_data = make_request(:put, path, nil, query_params.compact)

        # Return the updated issue resource, mapped with potentially new status
        map_card_data(card_data, card_data["idBoard"])
      end

      # Adds a comment to a Card in Trello.
      # @param card_id [String] The ID of the Trello Card.
      # @param comment_body [String] The comment text (Markdown).
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Comment] The created comment resource.
      def add_comment(card_id, comment_body, context = {})
        path = "cards/#{card_id}/actions/comments"
        query_params = { text: comment_body }
        comment_data = make_request(:post, path, nil, query_params)
        map_comment_action_data(comment_data, card_id)
      end

      # Parses an incoming Trello webhook payload.
      # @param request_body [String] The raw JSON request body.
      # @param headers [Hash] Request headers (unused).
      # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
      def parse_webhook(request_body, headers = {})
        payload = JSON.parse(request_body) rescue nil
        return nil unless payload.is_a?(Hash) && payload["action"].is_a?(Hash)

        action = payload["action"]
        action_type = action["type"]
        actor_data = action.dig("memberCreator")
        timestamp = Time.parse(action["date"]) rescue nil
        board_id = action.dig("data", "board", "id")
        card_data = action.dig("data", "card")
        comment_text = action.dig("data", "text")
        old_data = action.dig("data", "old") # For updateCard events

        event_type = nil
        object_kind = nil
        event_object_id = nil
        object_key = nil
        changes = nil
        object_data = nil

        case action_type
        when "createCard"
          event_type = :issue_created
          object_kind = :issue
          event_object_id = card_data["id"]
          object_key = card_data["idShort"]
        when "updateCard"
          event_type = :issue_updated
          object_kind = :issue
          event_object_id = card_data["id"]
          object_key = card_data["idShort"]
          # Parse changes for updateCard
          if old_data.is_a?(Hash)
            changes = {}
            old_data.each do |field, old_value|
              # Find the corresponding new value in the card data if possible
              new_value = card_data[field]
              changes[field.to_sym] = [ old_value, new_value ]
            end
          end
        when "commentCard"
          event_type = :comment_added
          object_kind = :comment
          event_object_id = action["id"] # Action ID is comment ID
          object_key = nil
        when "addMemberToCard", "removeMemberFromCard"
          event_type = :issue_updated
          object_kind = :issue
          event_object_id = card_data["id"]
          object_key = card_data["idShort"]
          changes = { assignees: true } # Indicate assignees changed, specific diff not easily available
        else
          return nil # Unhandled action type
        end

        WebhookEvent.new(
          event_type: event_type,
          object_kind: object_kind,
          event_object_id: event_object_id,
          object_key: object_key,
          project_id: board_id,
          actor: map_user_data(actor_data), # Use helper
          timestamp: timestamp,
          adapter_source: :trello,
          changes: changes,
          object_data: object_data, # Keep nil for now
          raw_data: payload
        )
      rescue JSON::ParserError
        nil # Ignore unparseable payloads
      end


      # Retrieves details for the currently authenticated user.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        user_data = make_request(:get, "members/me")
        map_user_data(user_data)
      end

      # Checks if the adapter can successfully authenticate and connect to the service.
      # Calls #get_current_user internally and catches authentication errors.
      # @return [Boolean] true if connection is successful, false otherwise.
      def connected?
        get_current_user
        true
      rescue ActiveProject::AuthenticationError
        false
      end


      private

      # Initializes the Faraday connection object.
      def initialize_connection
        Faraday.new(url: BASE_URL) do |conn|
          conn.request :retry
          conn.headers["Accept"] = "application/json"
          conn.response :raise_error
          conn.headers["User-Agent"] = ActiveProject.user_agent
        end
      end

      # Helper method for making requests.
      def make_request(method, path, body = nil, query_params = {})
        # Use config object for credentials
        auth_params = { key: @config.api_key, token: @config.api_token }
        all_params = auth_params.merge(query_params)
        json_body = body ? JSON.generate(body) : nil
        headers = {}
        headers["Content-Type"] = "application/json" if json_body

        response = @connection.run_request(method, path, json_body, headers) do |req|
          req.params.update(all_params)
        end

        return nil if response.status == 204 || response.body.empty?
        JSON.parse(response.body)
      rescue Faraday::Error => e
        handle_faraday_error(e)
      rescue JSON::ParserError => e
        raise ApiError.new("Trello API returned non-JSON response: #{response&.body}", original_error: e)
      end

      # Handles Faraday errors.
      def handle_faraday_error(error)
        status = error.response_status
        body = error.response_body
        message = body || "Unknown Trello Error"

        case status
        when 401, 403
          raise AuthenticationError, "Trello authentication/authorization failed (Status: #{status}): #{message}"
        when 404
          raise NotFoundError, "Trello resource not found (Status: 404): #{message}"
        when 429
          raise RateLimitError, "Trello rate limit exceeded (Status: 429): #{message}"
        when 400, 422
          if status == 400 && message&.include?("invalid id")
            raise NotFoundError, "Trello resource not found (Status: 400, Message: #{message})"
          else
            raise ValidationError.new("Trello validation failed (Status: #{status}): #{message}", status_code: status, response_body: body)
          end
        else
          raise ApiError.new("Trello API error (Status: #{status || 'N/A'}): #{message}", original_error: error, status_code: status, response_body: body)
        end
      end

      # Maps raw Trello card data hash to an Issue resource.
      def map_card_data(card_data, board_id)
        list_id = card_data["idList"]
        status = :open # Default status

        # Use stored config for status mappings
        board_mappings = @config.status_mappings[board_id]

        # Try mapping by List ID first (most reliable)
        if board_mappings && list_id && board_mappings.key?(list_id)
          status = board_mappings[list_id]
        # Fallback: Try mapping by List Name if ID mapping failed and list data is present
        elsif board_mappings && card_data["list"] && board_mappings.key?(card_data["list"]["name"])
           status = board_mappings[card_data["list"]["name"]]
        end

        # Override status if the card is archived (closed)
        status = :closed if card_data["closed"]

        created_timestamp = Time.at(card_data["id"][0..7].to_i(16)) rescue nil
        due_on = card_data["due"] ? Date.parse(card_data["due"]) : nil rescue nil

        Resources::Issue.new(self, # Pass adapter instance
          id: card_data["id"],
          key: nil,
          title: card_data["name"],
          description: card_data["desc"],
          status: status, # Use the determined status
          assignees: map_member_ids_to_users(card_data["idMembers"]), # Use new method
          reporter: nil, # Trello cards don't have a distinct reporter
          project_id: board_id,
          created_at: created_timestamp,
          updated_at: nil, # Trello API doesn't provide a standard updated_at for cards easily
          due_on: due_on,
          priority: nil, # Trello doesn't have priority
          adapter_source: :trello,
          raw_data: card_data
        )
      end

      # Maps raw Trello comment action data hash to a Comment resource.
      def map_comment_action_data(action_data, card_id)
        author_data = action_data.dig("memberCreator")
        comment_text = action_data.dig("data", "text")

        Resources::Comment.new(self, # Pass adapter instance
          id: action_data["id"],
          body: comment_text,
          author: map_user_data(author_data), # Use user mapping
          created_at: action_data["date"] ? Time.parse(action_data["date"]) : nil,
          updated_at: nil,
          issue_id: card_id,
          adapter_source: :trello,
          raw_data: action_data
        )
      end

      # Maps an array of Trello member IDs to an array of User resources.
      # Currently only populates the ID. Fetching full member details would require extra API calls.
      # @param member_ids [Array<String>, nil]
      # @return [Array<Resources::User>]
      def map_member_ids_to_users(member_ids)
        return [] unless member_ids.is_a?(Array)
        member_ids.map do |id|
          Resources::User.new(self, id: id, adapter_source: :trello, raw_data: { id: id })
        end
      end

      # Maps raw Trello member data hash to a User resource.
      # @param member_data [Hash, nil] Raw member data from Trello API.
      # @return [Resources::User, nil]
      def map_user_data(member_data)
        return nil unless member_data && member_data["id"]
        Resources::User.new(self, # Pass adapter instance
          id: member_data["id"],
          name: member_data["fullName"], # Trello uses fullName
          email: nil, # Trello API often doesn't provide email directly here
          adapter_source: :trello,
          raw_data: member_data
        )
      end
    end
  end
end
