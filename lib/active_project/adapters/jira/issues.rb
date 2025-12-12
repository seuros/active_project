# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Issues
        DEFAULT_FIELDS = %w[summary description status assignee reporter created updated project issuetype duedate
                            priority].freeze

        # Converts plain text to Atlassian Document Format (ADF)
        def adf_text(text)
          {
            type: "doc", version: 1,
            content: [ { type: "paragraph", content: [ { type: "text", text: text } ] } ]
          }
        end

        # Lists issues within a specific project, optionally filtered by JQL.
        # @param project_id_or_key [String, Integer] The ID or key of the project.
        # @param options [Hash] Optional filtering/pagination options. Accepts :jql, :fields, :start_at, :max_results.
        # @return [Array<ActiveProject::Resources::Issue>]
        def list_issues(project_id_or_key, options = {})
          start_at = options.fetch(:start_at, 0)
          max_results = options.fetch(:max_results, 50)
          jql = options.fetch(:jql, "project = '#{project_id_or_key}' ORDER BY created DESC")
          fields = options[:fields] || DEFAULT_FIELDS

          all_issues = []
          path = "/rest/api/3/search"

          payload = {
            jql: jql,
            startAt: start_at,
            maxResults: max_results,
            fields: fields
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
        # @param context [Hash] Optional context. Accepts :fields for field selection.
        # @return [ActiveProject::Resources::Issue]
        def find_issue(id_or_key, context = {})
          fields = context[:fields] || DEFAULT_FIELDS
          fields_param = fields.is_a?(Array) ? fields.join(",") : fields
          path = "/rest/api/3/issue/#{id_or_key}?fields=#{fields_param}"

          issue_data = make_request(:get, path)
          map_issue_data(issue_data)
        end

        # Creates a new issue in Jira using the V3 endpoint.
        # @param _project_id_or_key [String, Integer] Ignored (project info is in attributes).
        # @param attributes [Hash] Issue attributes.
        #   Required: :project, :summary, :issue_type.
        #   Optional: :description, :assignee_id, :due_on, :priority.
        # @return [ActiveProject::Resources::Issue]
        def create_issue(_project_id_or_key, attributes)
          path = "/rest/api/3/issue"

          unless attributes[:project].is_a?(Hash) && (attributes[:project][:id] || attributes[:project][:key]) &&
                 attributes[:summary] && !attributes[:summary].empty? &&
                 attributes[:issue_type] && (attributes[:issue_type][:id] || attributes[:issue_type][:name])
            raise ArgumentError,
                  "Missing required attributes for issue creation: :project (Hash with id/key), " \
                  ":summary, :issue_type (with id/name)"
          end

          fields_payload = {
            project: attributes[:project],
            summary: attributes[:summary],
            issuetype: attributes[:issue_type]
          }

          if attributes.key?(:description)
            fields_payload[:description] = if attributes[:description].is_a?(String)
                                             adf_text(attributes[:description])
            elsif attributes[:description].is_a?(Hash)
                                             attributes[:description]
            end
          end

          fields_payload[:assignee] = { accountId: attributes[:assignee_id] } if attributes.key?(:assignee_id)

          if attributes.key?(:due_on)
            fields_payload[:duedate] =
              attributes[:due_on].respond_to?(:strftime) ? attributes[:due_on].strftime("%Y-%m-%d") : attributes[:due_on]
          end

          fields_payload[:priority] = attributes[:priority] if attributes.key?(:priority)

          fields_payload[:parent] = attributes[:parent] if attributes.key?(:parent)

          payload = { fields: fields_payload }.to_json
          response_data = make_request(:post, path, payload)

          find_issue(response_data["key"])
        end

        # Updates an existing issue in Jira using the V3 endpoint.
        # @param id_or_key [String, Integer] The ID or key of the issue to update.
        # @param attributes [Hash] Issue attributes to update (e.g., :summary, :description, :assignee_id, :due_on, :priority).
        # @param context [Hash] Optional context. Accepts :fields for field selection on return.
        # @return [ActiveProject::Resources::Issue]
        def update_issue(id_or_key, attributes, context = {})
          raise ArgumentError, "attributes must be a Hash" unless attributes.is_a?(Hash)

          path = "/rest/api/3/issue/#{id_or_key}"

          update_fields = {}
          update_fields[:summary] = attributes[:summary] if attributes.key?(:summary)

          if attributes.key?(:description)
            update_fields[:description] = if attributes[:description].is_a?(String)
                                            adf_text(attributes[:description])
            elsif attributes[:description].is_a?(Hash)
                                            attributes[:description]
            end
          end

          if attributes.key?(:assignee_id)
            update_fields[:assignee] = attributes[:assignee_id] ? { accountId: attributes[:assignee_id] } : nil
          end

          if attributes.key?(:due_on)
            update_fields[:duedate] =
              attributes[:due_on].respond_to?(:strftime) ? attributes[:due_on].strftime("%Y-%m-%d") : attributes[:due_on]
          end

          update_fields[:priority] = attributes[:priority] if attributes.key?(:priority)

          return find_issue(id_or_key, context) if update_fields.empty?

          payload = { fields: update_fields }.to_json
          make_request(:put, path, payload)

          find_issue(id_or_key, context)
        end

        # Deletes an issue from Jira.
        # @param id_or_key [String, Integer] The ID or key of the issue to delete.
        # @param context [Hash] Optional context. Accepts :delete_subtasks to indicate whether subtasks should be deleted.
        # @return [Boolean] True if successfully deleted.
        def delete_issue(id_or_key, context = {})
          delete_subtasks = context[:delete_subtasks] || false
          path = "/rest/api/3/issue/#{id_or_key}"
          query = { deleteSubtasks: delete_subtasks }

          make_request(:delete, path, nil, query)
          true
        end
      end
    end
  end
end
