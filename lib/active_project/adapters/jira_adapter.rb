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
      attr_reader :config # Store the config object

      # Initializes the Jira Adapter.
      # @param config [Configurations::BaseAdapterConfiguration] The configuration object for Jira.
      # @raise [ArgumentError] if required configuration options (:site_url, :username, :api_token) are missing.
      def initialize(config:)
        # For now, Jira uses the base config. If specific Jira options are added,
        # create JiraConfiguration and check for that type.
        unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
          raise ArgumentError, "JiraAdapter requires a BaseAdapterConfiguration object"
        end
        @config = config

        # Validate presence of required config options within the config object
        unless @config.options[:site_url] && !@config.options[:site_url].empty? &&
               @config.options[:username] && !@config.options[:username].empty? &&
               @config.options[:api_token] && !@config.options[:api_token].empty?
          raise ArgumentError, "JiraAdapter configuration requires :site_url, :username, and :api_token"
        end

        @connection = initialize_connection
      end

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


      # --- Implementation of Base methods ---

      # Lists projects accessible by the configured credentials using the V3 endpoint.
      # Handles pagination automatically.
      # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
      def list_projects
        start_at = 0
        max_results = 50 # Jira default is 50
        all_projects = []

        loop do
          path = "/rest/api/3/project/search?startAt=#{start_at}&maxResults=#{max_results}"
          # make_request now handles the auth check internally
          response_data = make_request(:get, path)

          projects_data = response_data["values"] || []
          break if projects_data.empty?

          projects_data.each do |project_data|
            all_projects << Resources::Project.new(self, # Pass adapter instance
              id: project_data["id"], # Convert to integer
              key: project_data["key"],
              name: project_data["name"],
              adapter_source: :jira,
              raw_data: project_data
            )
          end

          # Check if this is the last page
          is_last = response_data["isLast"]
          break if is_last || projects_data.size < max_results # Exit if last page or less than max results returned

          start_at += projects_data.size
        end

        all_projects
      end

      # Finds a specific project by its ID or key.
      # @param id_or_key [String, Integer] The ID or key of the project.
      # @return [ActiveProject::Resources::Project] The project resource.
      def find_project(id_or_key)
        path = "/rest/api/3/project/#{id_or_key}"
        project_data = make_request(:get, path)

        Resources::Project.new(self, # Pass adapter instance
          id: project_data["id"].to_i, # Convert to integer
          key: project_data["key"],
          name: project_data["name"],
          adapter_source: :jira,
          raw_data: project_data
        )
      end

      # Creates a new project in Jira.
      # @param attributes [Hash] Project attributes. Required: :key, :name, :project_type_key, :lead_account_id. Optional: :description, :assignee_type.
      # @return [ActiveProject::Resources::Project] The created project resource.
      def create_project(attributes)
        # Validate required attributes
        required_keys = [ :key, :name, :project_type_key, :lead_account_id ]
        missing_keys = required_keys.reject { |k| attributes.key?(k) && !attributes[k].to_s.empty? }
        unless missing_keys.empty?
          raise ArgumentError, "Missing required attributes for Jira project creation: #{missing_keys.join(', ')}"
        end

        path = "/rest/api/3/project"
        payload = {
          key: attributes[:key],
          name: attributes[:name],
          projectTypeKey: attributes[:project_type_key],
          leadAccountId: attributes[:lead_account_id],
          description: attributes[:description],
          assigneeType: attributes[:assignee_type]
        }.compact # Use compact to remove optional nil values

        project_data = make_request(:post, path, payload.to_json)

        # Map response to Project resource
        Resources::Project.new(self, # Pass adapter instance
          id: project_data["id"]&.to_i, # Convert to integer
          key: project_data["key"],
          name: project_data["name"], # Name might not be in create response, fetch if needed?
          adapter_source: :jira,
          raw_data: project_data
        )
      end


      # Deletes a project in Jira.
      # WARNING: This is a permanent deletion and requires admin permissions.
      # @param project_id_or_key [String, Integer] The ID or key of the project to delete.
      # @return [Boolean] true if deletion was successful (API returns 204).
      # @raise [NotFoundError] if the project is not found.
      # @raise [AuthenticationError] if credentials lack permission.
      # @raise [ApiError] for other errors.
      def delete_project(project_id_or_key)
        path = "/rest/api/3/project/#{project_id_or_key}"
        make_request(:delete, path) # DELETE returns 204 No Content on success
        true # Return true if make_request doesn't raise an error
      end


      # Note: create_list is not implemented for Jira as statuses and workflows
      # are typically managed via the Jira UI or more complex API interactions,
      # not simple list creation. The base class raises NotImplementedError.


      # Lists issues within a specific project, optionally filtered by JQL.
      # @param project_id_or_key [String, Integer] The ID or key of the project.
      # @param options [Hash] Optional filtering/pagination options.
      # @return [Array<ActiveProject::Resources::Issue>] An array of issue resources.
      def list_issues(project_id_or_key, options = {})
        start_at = options.fetch(:start_at, 0)
        max_results = options.fetch(:max_results, 50)
        jql = options.fetch(:jql, "project = '#{project_id_or_key}' ORDER BY created DESC")

        all_issues = []
        path = "/rest/api/3/search" # Using V3 search for issues

        payload = {
          jql: jql,
          startAt: start_at,
          maxResults: max_results,
          # Request specific fields for efficiency
          fields: [ "summary", "description", "status", "assignee", "reporter", "created", "updated", "project", "issuetype", "duedate", "priority" ]
        }.to_json

        response_data = make_request(:post, path, payload)

        issues_data = response_data["issues"] || []
        issues_data.each do |issue_data|
          all_issues << map_issue_data(issue_data)
        end

        all_issues
      end

      # Finds a specific issue by its ID or key using the V3 endpoint.
      # @param id_or_key [String, Integer] The ID or key of the issue.
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Issue] The issue resource.
      def find_issue(id_or_key, context = {})
        fields = "summary,description,status,assignee,reporter,created,updated,project,issuetype,duedate,priority"
        path = "/rest/api/3/issue/#{id_or_key}?fields=#{fields}" # Using V3

        issue_data = make_request(:get, path)
        map_issue_data(issue_data)
      end

      # Creates a new issue in Jira using the V3 endpoint.
      # @param _project_id_or_key [String, Integer] Ignored (project info is in attributes).
      # @param attributes [Hash] Issue attributes. Required: :project, :summary, :issue_type. Optional: :description, :assignee_id, :due_on, :priority.
      # @return [ActiveProject::Resources::Issue] The created issue resource.
      def create_issue(_project_id_or_key, attributes)
        path = "/rest/api/3/issue" # Using V3

        unless attributes[:project] && (attributes[:project][:id] || attributes[:project][:key]) &&
               attributes[:summary] && !attributes[:summary].empty? &&
               attributes[:issue_type] && (attributes[:issue_type][:id] || attributes[:issue_type][:name])
          raise ArgumentError, "Missing required attributes for issue creation: :project (with id/key), :summary, :issue_type (with id/name)"
        end

        fields_payload = {
          project: attributes[:project],
          summary: attributes[:summary],
          issuetype: attributes[:issue_type]
        }

        # Handle description conversion to ADF
        if attributes.key?(:description)
          fields_payload[:description] = if attributes[:description].is_a?(String)
                                           { type: "doc", version: 1, content: [ { type: "paragraph", content: [ { type: "text", text: attributes[:description] } ] } ] }
          elsif attributes[:description].is_a?(Hash)
                                           attributes[:description] # Assume pre-formatted ADF
          end # nil description is handled by Jira if key is absent
        end

        # Map assignee if provided (expects accountId)
        if attributes.key?(:assignee_id)
          fields_payload[:assignee] = { accountId: attributes[:assignee_id] }
        end
        # Map due date if provided
        if attributes.key?(:due_on)
          fields_payload[:duedate] = attributes[:due_on].respond_to?(:strftime) ? attributes[:due_on].strftime("%Y-%m-%d") : attributes[:due_on]
        end
        # Map priority if provided
        if attributes.key?(:priority)
          fields_payload[:priority] = attributes[:priority] # Expects { name: 'High' } or { id: '...' }
        end
        # TODO: Map other common attributes (:labels) to fields_payload

        payload = { fields: fields_payload }.to_json
        response_data = make_request(:post, path, payload)

        # Fetch the full issue after creation to return consistent data
        find_issue(response_data["key"])
      end

      # Updates an existing issue in Jira using the V3 endpoint.
      # @param id_or_key [String, Integer] The ID or key of the issue to update.
      # @param attributes [Hash] Issue attributes to update (e.g., :summary, :description, :assignee_id, :due_on, :priority).
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Issue] The updated issue resource.
      def update_issue(id_or_key, attributes, context = {})
        path = "/rest/api/3/issue/#{id_or_key}" # Using V3

        update_fields = {}
        update_fields[:summary] = attributes[:summary] if attributes.key?(:summary)

        if attributes.key?(:description)
          update_fields[:description] = if attributes[:description].is_a?(String)
                                          { type: "doc", version: 1, content: [ { type: "paragraph", content: [ { type: "text", text: attributes[:description] } ] } ] }
          elsif attributes[:description].is_a?(Hash)
                                          attributes[:description] # Assume pre-formatted ADF
          else # Allow clearing description by passing nil explicitly
                                          nil
          end
        end

        # Map assignee if provided (expects accountId)
        if attributes.key?(:assignee_id)
          # Allow passing nil to unassign
          update_fields[:assignee] = attributes[:assignee_id] ? { accountId: attributes[:assignee_id] } : nil
        end
        # Map due date if provided
        if attributes.key?(:due_on)
          update_fields[:duedate] = attributes[:due_on].respond_to?(:strftime) ? attributes[:due_on].strftime("%Y-%m-%d") : attributes[:due_on]
        end
        # Map priority if provided
        if attributes.key?(:priority)
          update_fields[:priority] = attributes[:priority] # Expects { name: 'High' } or { id: '...' }
        end
        # TODO: Map other common attributes for update

        return find_issue(id_or_key) if update_fields.empty? # No fields to update

        payload = { fields: update_fields }.to_json
        make_request(:put, path, payload) # PUT returns 204 No Content on success

        # Fetch the updated issue to return consistent data
        find_issue(id_or_key)
      end

      # Adds a comment to an issue in Jira using the V3 endpoint.
      # @param issue_id_or_key [String, Integer] The ID or key of the issue.
      # @param comment_body [String] The text of the comment.
      # @param context [Hash] Optional context (ignored).
      # @return [ActiveProject::Resources::Comment] The created comment resource.
      def add_comment(issue_id_or_key, comment_body, context = {})
        path = "/rest/api/3/issue/#{issue_id_or_key}/comment" # Using V3

        # Construct basic ADF payload for the comment body
        payload = {
          body: {
            type: "doc", version: 1,
            content: [ { type: "paragraph", content: [ { type: "text", text: comment_body } ] } ]
          }
        }.to_json

        comment_data = make_request(:post, path, payload)
        map_comment_data(comment_data, issue_id_or_key)
      end

      # Transitions a Jira issue to a new status by finding and executing the appropriate workflow transition.
      # @param issue_id_or_key [String, Integer] The ID or key of the issue.
      # @param target_status_name_or_id [String, Integer] The name or ID of the target status.
      # @param options [Hash] Optional parameters for the transition (e.g., :resolution, :comment).
      #   - :resolution [Hash] e.g., `{ name: 'Done' }`
      #   - :comment [String] Comment body to add during transition.
      # @return [Boolean] true if successful.
      # @raise [NotFoundError] if the issue or target transition is not found.
      # @raise [ApiError] for other API errors.
      def transition_issue(issue_id_or_key, target_status_name_or_id, options = {})
        # 1. Get available transitions
        transitions_path = "/rest/api/3/issue/#{issue_id_or_key}/transitions"
        begin
          response_data = make_request(:get, transitions_path)
        rescue NotFoundError
          # Re-raise with a more specific message if the issue itself wasn't found
          raise NotFoundError, "Jira issue '#{issue_id_or_key}' not found."
        end
        available_transitions = response_data["transitions"] || []

        # 2. Find the target transition by name or ID (case-insensitive for name)
        target_transition = available_transitions.find do |t|
          t["id"] == target_status_name_or_id.to_s ||
          t.dig("to", "name")&.casecmp?(target_status_name_or_id.to_s) ||
          t.dig("to", "id") == target_status_name_or_id.to_s
        end

        unless target_transition
          available_names = available_transitions.map { |t| t.dig("to", "name") }.compact.join(", ")
          raise NotFoundError, "Target transition '#{target_status_name_or_id}' not found or not available for issue '#{issue_id_or_key}'. Available transitions: [#{available_names}]"
        end

        # 3. Construct payload for executing the transition
        payload = {
          transition: { id: target_transition["id"] }
        }

        # Add optional fields like resolution
        if options[:resolution]
          payload[:fields] ||= {}
          payload[:fields][:resolution] = options[:resolution]
        end

        # Add optional comment
        if options[:comment] && !options[:comment].empty?
          payload[:update] ||= {}
          payload[:update][:comment] ||= []
          payload[:update][:comment] << {
            add: {
              body: {
                type: "doc", version: 1,
                content: [ { type: "paragraph", content: [ { type: "text", text: options[:comment] } ] } ]
              }
            }
          }
        end

        # 4. Execute the transition
        make_request(:post, transitions_path, payload.to_json)
        true # POST returns 204 No Content on success, make_request doesn't raise error
      rescue Faraday::Error => e
        # Let handle_faraday_error raise the appropriate specific error
        handle_faraday_error(e)
        # We shouldn't reach here if handle_faraday_error raises, but as a fallback:
        raise ApiError.new("Failed to transition Jira issue '#{issue_id_or_key}'", original_error: e)
      end

      # Parses an incoming Jira webhook payload.
      # @param request_body [String] The raw JSON request body.
      # @param headers [Hash] Request headers.
      # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
      def parse_webhook(request_body, headers = {})
        payload = JSON.parse(request_body) rescue nil
        return nil unless payload.is_a?(Hash)

        event_name = payload["webhookEvent"]
        timestamp = payload["timestamp"] ? Time.at(payload["timestamp"] / 1000) : nil
        # Determine actor based on event type
        actor_data = if event_name.start_with?("comment_")
                       payload.dig("comment", "author")
        else
                       payload["user"] # User for issue events
        end
        issue_data = payload["issue"]
        comment_data = payload["comment"]
        changelog = payload["changelog"] # For issue_updated

        event_type = nil
        object_kind = nil
        object_id = nil
        object_key = nil
        project_id = nil
        changes = nil
        object_data = nil

        case event_name
        when "jira:issue_created"
          event_type = :issue_created
          object_kind = :issue
          event_object_id = issue_data["id"]
          object_key = issue_data["key"]
          project_id = issue_data.dig("fields", "project", "id")&.to_i
        when "jira:issue_updated"
          event_type = :issue_updated
          object_kind = :issue
          event_object_id = issue_data["id"]
          object_key = issue_data["key"]
          project_id = issue_data.dig("fields", "project", "id")&.to_i
          changes = parse_changelog(changelog)
        when "comment_created"
          event_type = :comment_added
          object_kind = :comment
          event_object_id = comment_data["id"]
          object_key = nil
          project_id = issue_data.dig("fields", "project", "id")&.to_i
        when "comment_updated"
          event_type = :comment_updated
          object_kind = :comment
          event_object_id = comment_data["id"]
          object_key = nil
          project_id = issue_data.dig("fields", "project", "id")&.to_i
        else
          return nil # Unhandled event type
        end

        WebhookEvent.new(
          event_type: event_type,
          object_kind: object_kind,
          event_object_id: event_object_id,
          object_key: object_key,
          project_id: project_id,
          actor: map_user_data(actor_data),
          timestamp: timestamp,
          adapter_source: :jira,
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
      def initialize_connection
        # Read connection details from the config object
        site_url = @config.options[:site_url].chomp("/")
        username = @config.options[:username]
        api_token = @config.options[:api_token]

        Faraday.new(url: site_url) do |conn|
          conn.request :authorization, :basic, username, api_token
          conn.request :retry
          # Important: Keep raise_error middleware *after* retry
          # conn.response :raise_error # Defer raising error to handle_faraday_error
          conn.headers["Content-Type"] = "application/json"
          conn.headers["Accept"] = "application/json"
          conn.headers["User-Agent"] = ActiveProject.user_agent
        end
      end

      # Makes an HTTP request. Returns parsed JSON or raises appropriate error.
      def make_request(method, path, body = nil)
        response = @connection.run_request(method, path, body, nil)

        # Check for AUTHENTICATED_FAILED header even on 200 OK
        if response.status == 200 && response.headers["x-seraph-loginreason"]&.include?("AUTHENTICATED_FAILED")
          raise AuthenticationError, "Jira authentication failed (X-Seraph-Loginreason: AUTHENTICATED_FAILED)"
        end

        # Check for other errors if not successful
        handle_faraday_error(response) unless response.success?

        # Return parsed body on success, or nil if body is empty/invalid
        JSON.parse(response.body) if response.body && !response.body.empty?
      rescue JSON::ParserError => e
         # Raise specific error if JSON parsing fails on a successful response body
         raise ApiError.new("Jira API returned non-JSON response: #{response&.body}", original_error: e)
      rescue Faraday::Error => e
        # Handle connection errors etc. that occur before the response object is available
        status = e.response&.status
        body = e.response&.body
        raise ApiError.new("Jira API connection error (Status: #{status || 'N/A'}): #{e.message}", original_error: e, status_code: status, response_body: body)
      end

      # Handles Faraday errors based on the response object (for non-2xx responses).
      def handle_faraday_error(response)
        status = response.status
        body = response.body
        # headers = response.headers # Headers already checked in make_request for the special case
        parsed_body = JSON.parse(body) rescue {}
        error_messages = parsed_body["errorMessages"] || [ parsed_body["message"] ].compact || []
        errors_hash = parsed_body["errors"] || {}
        message = error_messages.join(", ")

        # No need to check the 200 OK + header case here anymore

        case status
        when 401, 403
          raise AuthenticationError, "Jira authentication failed (Status: #{status})#{': ' + message unless message.empty?}"
        when 404
          raise NotFoundError, "Jira resource not found (Status: 404)#{': ' + message unless message.empty?}"
        when 429
          raise RateLimitError, "Jira rate limit exceeded (Status: 429)"
        when 400, 422
          raise ValidationError.new("Jira validation failed (Status: #{status})#{': ' + message unless message.empty?}. Errors: #{errors_hash.inspect}", errors: errors_hash, status_code: status, response_body: body)
        else
          # Raise generic ApiError for other non-success statuses
          raise ApiError.new("Jira API error (Status: #{status || 'N/A'})#{': ' + message unless message.empty?}", status_code: status, response_body: body)
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
          raw_data: issue_data
        )
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
          raw_data: comment_data
        )
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
          raw_data: user_data
        )
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
