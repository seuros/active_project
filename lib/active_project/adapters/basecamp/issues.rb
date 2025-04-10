# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Issues
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
            todos_data = begin
              JSON.parse(response.body)
            rescue StandardError
              []
            end
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
            raise ArgumentError,
                  "Missing required context: :project_id must be provided for BasecampAdapter#update_issue"
          end

          put_payload = {}
          put_payload[:content] = attributes[:title] if attributes.key?(:title)
          put_payload[:description] = attributes[:description] if attributes.key?(:description)
          if attributes.key?(:due_on)
            due_on_val = attributes[:due_on]
            put_payload[:due_on] = due_on_val.respond_to?(:strftime) ? due_on_val.strftime("%Y-%m-%d") : due_on_val
          end
          put_payload[:assignee_ids] = attributes[:assignee_ids] if attributes.key?(:assignee_ids)

          status_change_required = attributes.key?(:status)
          target_status = attributes[:status] if status_change_required

          unless !put_payload.empty? || status_change_required
            raise ArgumentError, "No attributes provided to update for BasecampAdapter#update_issue"
          end

          unless put_payload.empty?
            put_path = "buckets/#{project_id}/todos/#{todo_id}.json"
            make_request(:put, put_path, put_payload.compact.to_json)
          end

          if status_change_required
            completion_path = "buckets/#{project_id}/todos/#{todo_id}/completion.json"
            begin
              if target_status == :closed
                make_request(:post, completion_path)
              elsif target_status == :open
                make_request(:delete, completion_path)
              end
            rescue NotFoundError
              raise unless target_status == :open
            end
          end

          find_issue(todo_id, context)
        end
      end
    end
  end
end
