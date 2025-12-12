# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "time"

module ActiveProject
  module Adapters
    # Adapter for interacting with the Fizzy API.
    # Fizzy is a Kanban-style project tracking tool by 37signals.
    # Implements the interface defined in ActiveProject::Adapters::Base.
    # API Docs: https://github.com/basecamp/fizzy (see docs/API.md)
    class FizzyAdapter < Base
      attr_reader :config, :base_url

      include Fizzy::Connection
      include Fizzy::Projects
      include Fizzy::Issues
      include Fizzy::Comments
      include Fizzy::Columns

      # --- Resource Factories ---

      # Returns a factory for Project resources (Boards).
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

      # Retrieves details for the currently authenticated user.
      # Uses /my/identity endpoint which returns accounts and user info.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        # Fizzy's /my/identity is at the root, not under account_slug
        # We need to make a request to the base URL without the account_slug
        base_without_slug = @base_url.sub(%r{/\d+/$}, "/")
        response = @connection.get("#{base_without_slug}my/identity")
        identity_data = parse_response(response)

        # Get the first account's user data
        first_account = identity_data["accounts"]&.first
        return nil unless first_account

        user_data = first_account["user"]
        map_user_data(user_data)
      rescue Faraday::Error => e
        handle_faraday_error(e)
      end

      # Checks if the adapter can successfully authenticate and connect to the service.
      # @return [Boolean] true if connection is successful, false otherwise.
      def connected?
        get_current_user
        true
      rescue ActiveProject::AuthenticationError
        false
      end

      private

      # Helper method for making requests.
      def make_request(method, path, body = nil, query = {})
        request(method, path, body: body, query: query)
      end

      # Parses JSON response body.
      def parse_response(response)
        return {} if response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        {}
      end

      # Extracts relative path from full URL.
      def extract_path_from_url(url)
        url.sub(@base_url, "").sub(%r{^/}, "")
      end

      # Parses the 'next' link URL from the Link header.
      def parse_next_link(link_header)
        return nil unless link_header

        links = link_header.split(",").map(&:strip)
        next_link = links.find { |link| link.end_with?('rel="next"') }
        return nil unless next_link

        match = next_link.match(/<([^>]+)>/)
        match ? match[1] : nil
      end

      # Handles Faraday errors.
      def handle_faraday_error(error)
        status = error.response_status
        body = error.response_body

        parsed_body = begin
          JSON.parse(body)
        rescue StandardError
          { "error" => body }
        end
        message = parsed_body["error"] || parsed_body["message"] || "Unknown Fizzy Error"

        case status
        when 401, 403
          raise AuthenticationError, "Fizzy authentication/authorization failed (Status: #{status}): #{message}"
        when 404
          raise NotFoundError, "Fizzy resource not found (Status: 404): #{message}"
        when 429
          retry_after = error.response_headers&.dig("Retry-After")
          msg = "Fizzy rate limit exceeded (Status: 429)"
          msg += ". Retry after #{retry_after} seconds." if retry_after
          raise RateLimitError, msg
        when 400, 422
          raise ValidationError.new("Fizzy validation failed (Status: #{status}): #{message}",
                                    status_code: status, response_body: body)
        else
          raise ApiError.new("Fizzy API error (Status: #{status || 'N/A'}): #{message}",
                             original_error: error, status_code: status, response_body: body)
        end
      end

      # Maps raw Fizzy User data hash to a User resource.
      # @param user_data [Hash, nil] Raw user data from Fizzy API.
      # @return [Resources::User, nil]
      def map_user_data(user_data)
        return nil unless user_data && user_data["id"]

        Resources::User.new(
          self,
          id: user_data["id"],
          name: user_data["name"],
          email: user_data["email_address"],
          adapter_source: :fizzy,
          raw_data: user_data
        )
      end
    end
  end
end
