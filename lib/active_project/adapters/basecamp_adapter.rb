# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "time"

module ActiveProject
  module Adapters
    # Adapter for interacting with the Basecamp 3 API.
    # Implements the interface defined in ActiveProject::Adapters::Base.
    # API Docs: https://github.com/basecamp/bc3-api
    class BasecampAdapter < Base
      attr_reader :config, :base_url

      include Basecamp::Connection
      include Basecamp::Projects
      include Basecamp::Issues
      include Basecamp::Comments
      include Basecamp::Lists
      include Basecamp::Webhooks

      # --- Resource Factories ---

      # Returns a factory for Project resources.
      # @return [ResourceFactory<Resources::Project>]
      def projects
        ResourceFactory.new(adapter: self, resource_class: Resources::Project)
      end

      # Returns a factory for Issue resources (To-dos).
      # @return [ResourceFactory<Resources::Issue>]
      def issues
        ResourceFactory.new(adapter: self, resource_class: Resources::Issue)
      end

      # --- Implementation of Base methods ---

      # Retrieves details for the currently authenticated user.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        user_data = make_request(:get, "my/profile.json")
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
      def make_request(method, path, body = nil, query = {})
        request(method, path, body: body, query: query)
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
        message = parsed_body["error"] || parsed_body["message"] || "Unknown Basecamp Error"

        case status
        when 401, 403
          raise AuthenticationError, "Basecamp authentication/authorization failed (Status: #{status}): #{message}"
        when 404
          raise NotFoundError, "Basecamp resource not found (Status: 404): #{message}"
        when 429
          retry_after = error.response_headers["Retry-After"]
          msg = "Basecamp rate limit exceeded (Status: 429)"
          msg += ". Retry after #{retry_after} seconds." if retry_after
          raise RateLimitError, msg
        when 400, 422
          raise ValidationError.new("Basecamp validation failed (Status: #{status}): #{message}", status_code: status,
                                                                                                  response_body: body)
        else
          raise ApiError.new("Basecamp API error (Status: #{status || 'N/A'}): #{message}", original_error: error,
                                                                                            status_code: status, response_body: body)
        end
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

      # Maps raw Basecamp To-do data hash to an Issue resource.
      def map_todo_data(todo_data, project_id)
        status = todo_data["completed"] ? :closed : :open
        # Map assignees using map_user_data
        assignees = (todo_data["assignees"] || []).map { |a| map_user_data(a) }.compact
        # Map reporter using map_user_data
        reporter = map_user_data(todo_data["creator"])

        Resources::Issue.new(self, # Pass adapter instance
                             id: todo_data["id"],
                             key: nil,
                             title: todo_data["content"],
                             description: todo_data["description"],
                             status: status,
                             assignees: assignees, # Use mapped User resources
                             reporter: reporter, # Use mapped User resource
                             project_id: project_id,
                             created_at: todo_data["created_at"] ? Time.parse(todo_data["created_at"]) : nil,
                             updated_at: todo_data["updated_at"] ? Time.parse(todo_data["updated_at"]) : nil,
                             due_on: todo_data["due_on"] ? Date.parse(todo_data["due_on"]) : nil,
                             priority: nil, # Basecamp doesn't have priority
                             adapter_source: :basecamp,
                             raw_data: todo_data)
      end

      # Maps raw Basecamp Person data hash to a User resource.
      # @param person_data [Hash, nil] Raw person data from Basecamp API.
      # @return [Resources::User, nil]
      def map_user_data(person_data)
        return nil unless person_data && person_data["id"]

        Resources::User.new(self, # Pass adapter instance
                            id: person_data["id"],
                            name: person_data["name"],
                            email: person_data["email_address"],
                            adapter_source: :basecamp,
                            raw_data: person_data)
      end

      # Helper to map Basecamp comment data to a Comment resource.
      def map_comment_data(comment_data, todo_id)
        Resources::Comment.new(self, # Pass adapter instance
                               id: comment_data["id"],
                               body: comment_data["content"], # HTML
                               author: map_user_data(comment_data["creator"]), # Use user mapping
                               created_at: comment_data["created_at"] ? Time.parse(comment_data["created_at"]) : nil,
                               updated_at: comment_data["updated_at"] ? Time.parse(comment_data["updated_at"]) : nil,
                               issue_id: todo_id.to_i,
                               adapter_source: :basecamp,
                               raw_data: comment_data)
      end

      # Finds the ID of the first todolist in a project.
    end
  end
end
