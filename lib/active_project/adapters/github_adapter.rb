# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "time"
require_relative "github/connection"
require_relative "github/projects"
require_relative "github/issues"
require_relative "github/webhooks"

module ActiveProject
  module Adapters
    # Adapter for interacting with the GitHub REST API.
    # Implements the interface defined in ActiveProject::Adapters::Base.
    # API Docs: https://docs.github.com/en/rest
    class GithubAdapter < Base
      attr_reader :config
      
      include Github::Connection
      include Github::Projects
      include Github::Issues
      include Github::Webhooks
      
      # Retrieves details for the currently authenticated user.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        user_data = make_request(:get, "user")
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
      
      # Returns a factory for Project resources.
      # In GitHub's context, this is for interacting with repositories.
      # @return [ResourceFactory<Resources::Project>]
      def projects
        ResourceFactory.new(adapter: self, resource_class: Resources::Project)
      end
      
      # Returns a factory for Issue resources.
      # @return [ResourceFactory<Resources::Issue>]
      def issues
        ResourceFactory.new(adapter: self, resource_class: Resources::Issue)
      end
      
      private
      
      # Helper method for making requests to the GitHub API.
      # @param method [Symbol] HTTP method (:get, :post, :patch, :delete, etc.)
      # @param path [String] API endpoint path
      # @param body [Hash, nil] Request body (for POST/PATCH requests)
      # @param query [Hash, nil] Query parameters
      # @return [Hash, Array, nil] Parsed JSON response or nil if response is empty
      # @raise [ActiveProject::ApiError] for various API errors
      def make_request(method, path, body = nil, query = nil)
        json_body = body ? JSON.generate(body) : nil
        
        response = @connection.run_request(method, path, json_body, nil) do |req|
          req.params = query if query
        end
        
        return nil if response.status == 204 || response.body.empty?
        
        JSON.parse(response.body)
      rescue Faraday::Error => e
        handle_faraday_error(e)
      rescue JSON::ParserError => e
        raise ApiError.new("GitHub API returned non-JSON response: #{response&.body}", original_error: e)
      end
      
      # Handles Faraday errors and converts them to appropriate ActiveProject error types.
      # @param error [Faraday::Error] The Faraday error to handle
      # @raise [ActiveProject::AuthenticationError] for 401/403 errors
      # @raise [ActiveProject::NotFoundError] for 404 errors
      # @raise [ActiveProject::ValidationError] for 422 errors
      # @raise [ActiveProject::RateLimitError] for 429 errors
      # @raise [ActiveProject::ApiError] for other errors
      def handle_faraday_error(error)
        status = error.response_status
        body = error.response_body
        
        begin
          parsed_body = JSON.parse(body)
          message = parsed_body["message"]
        rescue
          message = body || "Unknown GitHub Error"
        end
        
        case status
        when 401, 403
          raise AuthenticationError, "GitHub authentication failed (Status: #{status}): #{message}"
        when 404
          raise NotFoundError, "GitHub resource not found (Status: 404): #{message}"
        when 422
          raise ValidationError.new("GitHub validation failed (Status: 422): #{message}", 
                                   status_code: status, 
                                   response_body: body)
        when 429
          raise RateLimitError, "GitHub rate limit exceeded (Status: 429): #{message}"
        else
          raise ApiError.new("GitHub API error (Status: #{status || 'N/A'}): #{message}", 
                            original_error: error, 
                            status_code: status, 
                            response_body: body)
        end
      end
      
      # Maps raw GitHub user data hash to a User resource.
      # @param user_data [Hash, nil] Raw user data from GitHub API
      # @return [Resources::User, nil] The mapped user object or nil if user_data is nil
      def map_user_data(user_data)
        return nil unless user_data && user_data["id"]
        
        Resources::User.new(
          self,
          id: user_data["id"].to_s,
          name: user_data["login"],
          email: user_data["email"],
          adapter_source: :github,
          raw_data: user_data
        )
      end
    end
  end
end