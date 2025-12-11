# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "time"

module ActiveProject
  module Adapters
    # Adapter for interacting with the Jira REST API.
    # Implements the interface defined in ActiveProject::Adapters::Base.
    class JiraAdapter < Base
      include Jira::AttributeNormalizer

      attr_reader :config # Store the config object

      include Jira::Connection
      include Jira::Projects
      include Jira::Issues
      include Jira::Comments
      include Jira::Transitions
      include Jira::Webhooks

      # --- Resource Factories ---

      # Returns a factory for Project resources.
      # @return [ResourceFactory<Resources::Project>]
      def projects
        ResourceFactory.new(adapter: self, resource_class: Resources::Project)
      end

      # Returns a factory for Issue resources.
      # @return [ResourceFactory<Resources::Issue>]
      def issues
        ResourceFactory.new(adapter: self, resource_class: Resources::Issue)
      end

      # Creates an issue in Jira.
      # @param project_id_or_key [String, Integer] The project ID or key (used by Jira to determine project).
      # @param attributes [Hash] Issue attributes including :project, :summary, :issue_type.
      # @return [ActiveProject::Resources::Issue] The created issue.
      def create_issue(project_id_or_key, attributes)
        super(project_id_or_key, normalize_issue_attrs(attributes))
      end

      # Updates an issue in Jira.
      # @param id_or_key [String, Integer] The issue ID or key.
      # @param attributes [Hash] Attributes to update.
      # @param context [Hash] Optional context (e.g., :fields for return selection).
      # @return [ActiveProject::Resources::Issue] The updated issue.
      def update_issue(id_or_key, attributes, context = {})
        super(id_or_key, normalize_issue_attrs(attributes), context)
      end

      # Retrieves details for the currently authenticated user.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        user_data = make_request(:get, "/rest/api/3/myself")
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

      # Handles Faraday errors based on the response object (for non-2xx responses).
      def handle_faraday_error(response)
        status = response.status
        body = response.body
        # headers = response.headers # Headers already checked in make_request for the special case
        parsed_body = begin
          JSON.parse(body)
        rescue StandardError
          {}
        end
        error_messages = parsed_body["errorMessages"] || [ parsed_body["message"] ].compact || []
        errors_hash = parsed_body["errors"] || {}
        message = error_messages.join(", ")

        # No need to check the 200 OK + header case here anymore

        case status
        when 401, 403
          raise AuthenticationError,
                "Jira authentication failed (Status: #{status})#{": #{message}" unless message.empty?}"
        when 404
          raise NotFoundError, "Jira resource not found (Status: 404)#{": #{message}" unless message.empty?}"
        when 429
          raise RateLimitError, "Jira rate limit exceeded (Status: 429)"
        when 400, 422
          raise ValidationError.new(
            "Jira validation failed (Status: #{status})#{
              unless message.empty?
                ": #{message}"
              end}. Errors: #{errors_hash.inspect}", errors: errors_hash, status_code: status, response_body: body
          )
        else
          # Raise generic ApiError for other non-success statuses
          raise ApiError.new("Jira API error (Status: #{status || 'N/A'})#{": #{message}" unless message.empty?}",
                             status_code: status, response_body: body)
        end
      end

      # Maps raw Jira issue data hash to an Issue resource.
      def map_issue_data(issue_data)
        fields = issue_data && issue_data["fields"]
        # Ensure assignee is mapped correctly into an array
        assignee_user = fields && map_user_data(fields["assignee"])
        assignees_array = assignee_user ? [ assignee_user ] : []

        Resources::Issue.new(self, # Pass adapter instance
                             id: issue_data["id"], # Keep as string from Jira
                             key: issue_data["key"],
                             title: fields["summary"],
                             description: map_adf_description(fields["description"]),
                             status: normalize_jira_status(fields["status"]),
                             assignees: assignees_array, # Use the mapped array
                             reporter: map_user_data(fields["reporter"]),
                             project_id: fields.dig("project", "id")&.to_i, # Convert to integer
                             created_at: fields["created"] ? Time.parse(fields["created"]) : nil,
                             updated_at: fields["updated"] ? Time.parse(fields["updated"]) : nil,
                             due_on: fields["duedate"] ? Date.parse(fields["duedate"]) : nil,
                             priority: fields.dig("priority", "name"),
                             adapter_source: :jira,
                             raw_data: issue_data)
      end

      # Maps raw Jira comment data hash to a Comment resource.
      def map_comment_data(comment_data, issue_id_or_key)
        Resources::Comment.new(self, # Pass adapter instance
                               id: comment_data["id"],
                               body: map_adf_description(comment_data["body"]),
                               author: map_user_data(comment_data["author"]),
                               created_at: comment_data["created"] ? Time.parse(comment_data["created"]) : nil,
                               updated_at: comment_data["updated"] ? Time.parse(comment_data["updated"]) : nil,
                               issue_id: issue_id_or_key, # Store the issue context
                               adapter_source: :jira,
                               raw_data: comment_data)
      end

      # Maps raw Jira user data hash to a User resource.
      # @return [Resources::User, nil]
      def map_user_data(user_data)
        return nil unless user_data && user_data["accountId"]

        Resources::User.new(self, # Pass adapter instance
                            id: user_data["accountId"],
                            name: user_data["displayName"],
                            email: user_data["emailAddress"],
                            adapter_source: :jira,
                            raw_data: user_data)
      end

      # Basic parser for Atlassian Document Format (ADF).
      def map_adf_description(adf_data)
        return nil unless adf_data.is_a?(Hash) && adf_data["content"].is_a?(Array)

        adf_data["content"].map do |block|
          next unless block.is_a?(Hash) && block["content"].is_a?(Array)

          block["content"].map do |inline|
            inline["text"] if inline.is_a?(Hash) && inline["type"] == "text"
          end.compact.join
        end.compact.join("\n")
      end

      # Normalizes Jira status based on its category.
      def normalize_jira_status(status_data)
        return :unknown unless status_data.is_a?(Hash)

        category_key = status_data.dig("statusCategory", "key")
        case category_key
        when "new", "undefined" then :open
        when "indeterminate" then :in_progress
        when "done" then :closed
        else :unknown
        end
      end

      # Parses the changelog from a Jira webhook payload.
      def parse_changelog(changelog_data)
        return nil unless changelog_data.is_a?(Hash) && changelog_data["items"].is_a?(Array)

        changes = {}
        changelog_data["items"].each do |item|
          field_name = item["field"] || item["fieldId"]
          changes[field_name.to_sym] = [ item["fromString"] || item["from"], item["toString"] || item["to"] ]
        end
        changes.empty? ? nil : changes
      end
    end
  end
end
