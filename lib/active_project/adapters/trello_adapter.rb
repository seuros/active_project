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

      include Trello::Connection
      include Trello::Projects
      include Trello::Issues
      include Trello::Comments
      include Trello::Lists
      include Trello::Webhooks

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
        body = JSON.parse(body) if body.is_a?(String) && !body.empty? rescue body
        if body.is_a?(Hash)
          message = body["message"]
        end
        message ||= body || "Unknown Trello Error"

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
          end

          raise ValidationError.new("Trello validation failed (Status: #{status}): #{message}", status_code: status,
                                                                                                response_body: body)

        else
          raise ApiError.new("Trello API error (Status: #{status || 'N/A'}): #{message}", original_error: error,
                                                                                          status_code: status, response_body: body)
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

        created_timestamp = begin
          Time.at(card_data["id"][0..7].to_i(16))
        rescue StandardError
          nil
        end
        due_on = begin
          card_data["due"] ? Date.parse(card_data["due"]) : nil
        rescue StandardError
          nil
        end

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
                             raw_data: card_data)
      end

      # Maps raw Trello comment action data hash to a Comment resource.
      def map_comment_action_data(action_data, card_id)
        author_data = action_data["memberCreator"]
        comment_text = action_data.dig("data", "text")

        Resources::Comment.new(self, # Pass adapter instance
                               id: action_data["id"],
                               body: comment_text,
                               author: map_user_data(author_data), # Use user mapping
                               created_at: action_data["date"] ? Time.parse(action_data["date"]) : nil,
                               updated_at: nil,
                               issue_id: card_id,
                               adapter_source: :trello,
                               raw_data: action_data)
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
                            raw_data: member_data)
      end
    end
  end
end
