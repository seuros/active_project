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
      BASE_URL_TEMPLATE = "https://3.basecampapi.com/%<account_id>s/"

      attr_reader :config, :base_url

      # Initializes the Basecamp Adapter.
      # @param config [Configurations::BaseAdapterConfiguration] The configuration object for Basecamp.
      # @raise [ArgumentError] if required configuration options (:account_id, :access_token) are missing.
      def initialize(config:)
        # For now, Basecamp uses the base config. If specific Basecamp options are added,
        # create BasecampConfiguration and check for that type.
        unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
          raise ArgumentError, "BasecampAdapter requires a BaseAdapterConfiguration object"
        end
        @config = config

        account_id = @config.options[:account_id].to_s # Ensure it's a string
        access_token = @config.options[:access_token]

        unless account_id && !account_id.empty? && access_token && !access_token.empty?
          raise ArgumentError, "BasecampAdapter configuration requires :account_id and :access_token"
        end

        @base_url = format(BASE_URL_TEMPLATE, account_id: account_id)
        @connection = initialize_connection
      end

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

      # Lists projects accessible by the configured credentials.
      # Handles pagination automatically using the Link header.
      # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
      def list_projects
        all_projects = []
        path = "projects.json"

        loop do
          # Use connection directly to access headers for Link header parsing
          response = @connection.get(path)
          projects_data = JSON.parse(response.body) rescue []
          break if projects_data.empty?

          projects_data.each do |project_data|
            all_projects << Resources::Project.new(self, # Pass adapter instance
              id: project_data["id"],
              key: nil, # Basecamp doesn't have a short project key like Jira
              name: project_data["name"],
              adapter_source: :basecamp,
              raw_data: project_data
            )
          end

          # Handle pagination via Link header
          link_header = response.headers["Link"]
          next_url = parse_next_link(link_header)
          break unless next_url

          # Extract path from the next URL relative to the base URL
          path = next_url.sub(@base_url, "").sub(%r{^/}, "")
        end

        all_projects
      rescue Faraday::Error => e
        handle_faraday_error(e) # Ensure errors during GET are handled
      end

      # Finds a specific project by its ID.
      # @param project_id [String, Integer] The ID of the Basecamp project.
      # @return [ActiveProject::Resources::Project] The project resource.
      def find_project(project_id)
        path = "projects/#{project_id}.json"
        project_data = make_request(:get, path)
        return nil unless project_data

        # Raise NotFoundError if the project is trashed
        if project_data && project_data["status"] == "trashed"
          raise NotFoundError, "Basecamp project ID #{project_id} is trashed."
        end

        Resources::Project.new(self, # Pass adapter instance
          id: project_data["id"],
          key: nil,
          name: project_data["name"],
          adapter_source: :basecamp,
          raw_data: project_data
        )
        # Note: make_request handles raising NotFoundError on 404
      end

      # Creates a new project in Basecamp.
      # @param attributes [Hash] Project attributes. Required: :name. Optional: :description.
      # @return [ActiveProject::Resources::Project] The created project resource.
      def create_project(attributes)
        unless attributes[:name] && !attributes[:name].empty?
          raise ArgumentError, "Missing required attribute for Basecamp project creation: :name"
        end

        path = "projects.json"
        payload = {
          name: attributes[:name],
          description: attributes[:description]
        }.compact

        project_data = make_request(:post, path, payload.to_json)

        # Map response to Project resource
        Resources::Project.new(self, # Pass adapter instance
          id: project_data["id"],
          key: nil,
          name: project_data["name"],
          adapter_source: :basecamp,
          raw_data: project_data
        )
      end

      # Creates a new Todolist within a project.
      # @param project_id [String, Integer] The ID of the Basecamp project (bucket).
      # @param attributes [Hash] Todolist attributes. Required: :name. Optional: :description.
      # @return [Hash] The raw data hash of the created todolist.
      def create_list(project_id, attributes)
        unless attributes[:name] && !attributes[:name].empty?
          raise ArgumentError, "Missing required attribute for Basecamp todolist creation: :name"
        end

        # Need to find the 'todoset' ID first
        project_data = make_request(:get, "projects/#{project_id}.json")
        todoset_dock_entry = project_data&.dig("dock")&.find { |d| d["name"] == "todoset" }
        todoset_url = todoset_dock_entry&.dig("url")
        unless todoset_url
          raise ApiError, "Could not find todoset URL for project #{project_id}"
        end
        todoset_id = todoset_url.match(/todosets\/(\d+)\.json$/)&.captures&.first
        unless todoset_id
          raise ApiError, "Could not extract todoset ID from URL: #{todoset_url}"
        end

        path = "buckets/#{project_id}/todosets/#{todoset_id}/todolists.json"
        payload = {
          name: attributes[:name],
          description: attributes[:description]
        }.compact

        # POST returns the created todolist object
        make_request(:post, path, payload.to_json)
      end

      # Archives (trashes) a project in Basecamp.
      # Note: Basecamp API doesn't offer permanent deletion via this endpoint.
      # @param project_id [String, Integer] The ID of the project to trash.
      # @return [Boolean] true if trashing was successful (API returns 204).
      # @raise [NotFoundError] if the project is not found.
      # @raise [AuthenticationError] if credentials lack permission.
      # @raise [ApiError] for other errors.

      # Recovers a trashed project in Basecamp.
      # @param project_id [String, Integer] The ID of the project to recover.
      # @return [Boolean] true if recovery was successful (API returns 204).
      def untrash_project(project_id)
        path = "projects/#{project_id}.json"
        make_request(:put, path, { "status": "active" }.to_json)
        true # Return true if make_request doesn't raise an error
      end

      def delete_project(project_id)
        path = "projects/#{project_id}.json"
        make_request(:delete, path) # PUT returns 204 No Content on success
        true # Return true if make_request doesn't raise an error
      end

      # Lists To-dos within a specific project.
      # @param project_id [String, Integer] The ID of the Basecamp project.
      # @param options [Hash] Optional options. Accepts :todolist_id.
      # @return [Array<ActiveProject::Resources::Issue>] An array of issue resources.
      def list_issues(project_id, options = {})
        all_todos = []
        todolist_id = options[:todolist_id]

        unless todolist_id
          todolist_id = find_first_todolist_id(project_id)
          return [] unless todolist_id
        end

        path = "buckets/#{project_id}/todolists/#{todolist_id}/todos.json"

        loop do
          response = @connection.get(path)
          todos_data = JSON.parse(response.body) rescue []
          break if todos_data.empty?

          todos_data.each do |todo_data|
            all_todos << map_todo_data(todo_data, project_id)
          end

          link_header = response.headers["Link"]
          next_url = parse_next_link(link_header)
          break unless next_url

          path = next_url.sub(@base_url, "").sub(%r{^/}, "")
        end

        all_todos
      rescue Faraday::Error => e
        handle_faraday_error(e)
      end

      # Finds a specific To-do by its ID.
      # @param todo_id [String, Integer] The ID of the Basecamp To-do.
      # @param context [Hash] Required context: { project_id: '...' }.
      # @return [ActiveProject::Resources::Issue] The issue resource.
      def find_issue(todo_id, context = {})
        project_id = context[:project_id]
        unless project_id
          raise ArgumentError, "Missing required context: :project_id must be provided for BasecampAdapter#find_issue"
        end

        path = "buckets/#{project_id}/todos/#{todo_id}.json"
        todo_data = make_request(:get, path)
        map_todo_data(todo_data, project_id)
      end

      # Creates a new To-do in Basecamp.
      # @param project_id [String, Integer] The ID of the Basecamp project.
      # @param attributes [Hash] To-do attributes. Required: :todolist_id, :title. Optional: :description, :due_on, :assignee_ids.
      # @return [ActiveProject::Resources::Issue] The created issue resource.
      def create_issue(project_id, attributes)
        todolist_id = attributes[:todolist_id]
        title = attributes[:title]

        unless todolist_id && title && !title.empty?
          raise ArgumentError, "Missing required attributes for Basecamp to-do creation: :todolist_id, :title"
        end

        path = "buckets/#{project_id}/todolists/#{todolist_id}/todos.json"

        payload = {
          content: title,
          description: attributes[:description],
          due_on: attributes[:due_on].respond_to?(:strftime) ? attributes[:due_on].strftime("%Y-%m-%d") : attributes[:due_on],
          # Basecamp expects an array of numeric IDs for assignees
          assignee_ids: attributes[:assignee_ids]
        }.compact

        todo_data = make_request(:post, path, payload.to_json)
        map_todo_data(todo_data, project_id)
      end

      # Updates an existing To-do in Basecamp.
      # Handles updates to standard fields via PUT and status changes via POST/DELETE completion endpoints.
      # @param todo_id [String, Integer] The ID of the Basecamp To-do.
      # @param attributes [Hash] Attributes to update (e.g., :title, :description, :status, :assignee_ids, :due_on).
      # @param context [Hash] Required context: { project_id: '...' }.
      # @return [ActiveProject::Resources::Issue] The updated issue resource (fetched after updates).
      def update_issue(todo_id, attributes, context = {})
        project_id = context[:project_id]
        unless project_id
          raise ArgumentError, "Missing required context: :project_id must be provided for BasecampAdapter#update_issue"
        end

        # Separate attributes for PUT payload and status change
        put_payload = {}
        put_payload[:content] = attributes[:title] if attributes.key?(:title)
        put_payload[:description] = attributes[:description] if attributes.key?(:description)
        # Format due_on if present
        if attributes.key?(:due_on)
          due_on_val = attributes[:due_on]
          put_payload[:due_on] = due_on_val.respond_to?(:strftime) ? due_on_val.strftime("%Y-%m-%d") : due_on_val
        end
        put_payload[:assignee_ids] = attributes[:assignee_ids] if attributes.key?(:assignee_ids)

        status_change_required = attributes.key?(:status)
        target_status = attributes[:status] if status_change_required

        # Check if any update action is requested
        unless !put_payload.empty? || status_change_required
          raise ArgumentError, "No attributes provided to update for BasecampAdapter#update_issue"
        end

        # 1. Perform PUT request for standard fields if needed
        if !put_payload.empty?
          put_path = "buckets/#{project_id}/todos/#{todo_id}.json"
          # We make the request but ignore the immediate response body,
          # as it might not reflect the update immediately or consistently.
          make_request(:put, put_path, put_payload.compact.to_json)
        end

        # 2. Perform status change via completion endpoints if needed
        if status_change_required
          completion_path = "buckets/#{project_id}/todos/#{todo_id}/completion.json"
          begin
            if target_status == :closed
              # POST to complete - returns 204 No Content on success
              make_request(:post, completion_path)
            elsif target_status == :open
              # DELETE to reopen - returns 204 No Content on success
              make_request(:delete, completion_path)
              # else: Ignore invalid status symbols for now
            end
          rescue NotFoundError
            # Ignore 404 on DELETE if trying to reopen an already open todo
            raise unless target_status == :open
          end
        end

        # 3. Always fetch the final state after all updates are performed
        find_issue(todo_id, context)
      end

      # Adds a comment to a To-do in Basecamp.
      # @param todo_id [String, Integer] The ID of the Basecamp To-do.
      # @param comment_body [String] The comment text (HTML).
      # @param context [Hash] Required context: { project_id: '...' }.
      # @return [ActiveProject::Resources::Comment] The created comment resource.
      def add_comment(todo_id, comment_body, context = {})
        project_id = context[:project_id]
        unless project_id
          raise ArgumentError, "Missing required context: :project_id must be provided for BasecampAdapter#add_comment"
        end

        path = "buckets/#{project_id}/recordings/#{todo_id}/comments.json"
        payload = { content: comment_body }.to_json
        comment_data = make_request(:post, path, payload)
        map_comment_data(comment_data, todo_id.to_i)
      end

      # Parses an incoming Basecamp webhook payload.
      # @param request_body [String] The raw JSON request body.
      # @param headers [Hash] Request headers (unused).
      # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
      def parse_webhook(request_body, headers = {})
        payload = JSON.parse(request_body) rescue nil
        return nil unless payload.is_a?(Hash)

        kind = payload["kind"]
        recording = payload["recording"]
        creator = payload["creator"]
        timestamp = Time.parse(payload["created_at"]) rescue nil
        return nil unless recording && kind

        event_type = nil
        object_kind = nil
        event_object_id = recording["id"]
        object_key = nil
        project_id = recording.dig("bucket", "id")
        changes = nil
        object_data = nil

        case kind
        when /todo_created$/
          event_type = :issue_created
          object_kind = :issue
        when /todo_assignment_changed$/, /todo_completion_changed$/, /todo_content_updated$/, /todo_description_changed$/, /todo_due_on_changed$/
          event_type = :issue_updated
          object_kind = :issue
          # Changes could be parsed from payload['details'] if needed
        when /comment_created$/
          event_type = :comment_added
          object_kind = :comment
        when /comment_content_changed$/
          event_type = :comment_updated
          object_kind = :comment
        else
          return nil # Unhandled kind
        end

        WebhookEvent.new(
          event_type: event_type,
          object_kind: object_kind,
          event_object_id: event_object_id,
          object_key: object_key,
          project_id: project_id,
          actor: map_user_data(creator),
          timestamp: timestamp,
          adapter_source: :basecamp,
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
      def initialize_connection
        # Read connection details from the config object
        access_token = @config.options[:access_token]

        Faraday.new(url: @base_url) do |conn|
          conn.request :authorization, :bearer, access_token
          conn.request :retry
          conn.response :raise_error
          conn.headers["Content-Type"] = "application/json"
          conn.headers["Accept"] = "application/json"
          conn.headers["User-Agent"] = ActiveProject.user_agent
        end
      end

      # Helper method for making requests.
      def make_request(method, path, body = nil, query_params = {})
        full_path = path.start_with?("/") ? path[1..] : path

        response = @connection.run_request(method, full_path, body, nil) do |req|
          req.params.update(query_params) unless query_params.empty?
        end
        return nil if response.status == 204 # Handle No Content for POST/DELETE completion
        JSON.parse(response.body) if response.body && !response.body.empty?
      rescue Faraday::Error => e
        handle_faraday_error(e)
      end

      # Handles Faraday errors.
      def handle_faraday_error(error)
        status = error.response_status
        body = error.response_body

        parsed_body = JSON.parse(body) rescue { "error" => body }
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
          raise ValidationError.new("Basecamp validation failed (Status: #{status}): #{message}", status_code: status, response_body: body)
        else
          raise ApiError.new("Basecamp API error (Status: #{status || 'N/A'}): #{message}", original_error: error, status_code: status, response_body: body)
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
          raw_data: todo_data
        )
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
          raw_data: person_data
        )
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
          raw_data: comment_data
        )
      end

      # Finds the ID of the first todolist in a project.
      def find_first_todolist_id(project_id)
        project_data = make_request(:get, "projects/#{project_id}.json")
        todoset_dock_entry = project_data&.dig("dock")&.find { |d| d["name"] == "todoset" }
        todoset_url = todoset_dock_entry&.dig("url")
        return nil unless todoset_url
        todoset_id = todoset_url.match(/todosets\/(\d+)\.json$/)&.captures&.first
        return nil unless todoset_id
        todolists_url_path = "buckets/#{project_id}/todosets/#{todoset_id}/todolists.json"
        todolists_data = make_request(:get, todolists_url_path)
        todolists_data&.first&.dig("id")
      rescue NotFoundError
        nil
      end
    end
  end
end
