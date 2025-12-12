# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Projects
        # Lists projects accessible by the configured credentials using the V3 endpoint.
        # Handles pagination automatically.
        # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
        def list_projects
          start_at = 0
          max_results = 50
          all_projects = []

          loop do
            path = "/rest/api/3/project/search?startAt=#{start_at}&maxResults=#{max_results}"
            response_data = make_request(:get, path)

            projects_data = response_data["values"] || []
            break if projects_data.empty?

            projects_data.each do |project_data|
              all_projects << Resources::Project.new(self,
                                                     id: project_data["id"],
                                                     key: project_data["key"],
                                                     name: project_data["name"],
                                                     adapter_source: :jira,
                                                     raw_data: project_data)
            end

            is_last = response_data["isLast"]
            break if is_last || projects_data.size < max_results

            start_at += projects_data.size
          end

          all_projects
        end

        # Finds a specific project by its ID or key.
        # @param id_or_key [String, Integer] The ID or key of the project.
        # @return [ActiveProject::Resources::Project]
        def find_project(id_or_key)
          path = "/rest/api/3/project/#{id_or_key}"
          project_data = make_request(:get, path)

          Resources::Project.new(self,
                                 id: project_data["id"].to_i,
                                 key: project_data["key"],
                                 name: project_data["name"],
                                 adapter_source: :jira,
                                 raw_data: project_data)
        end

        # Creates a new project in Jira.
        # @param attributes [Hash] Project attributes.
        #   Required: :key, :name, :project_type_key, :lead_account_id.
        #   Optional: :description, :assignee_type.
        # @return [ActiveProject::Resources::Project]
        def create_project(attributes)
          required_keys = %i[key name project_type_key lead_account_id]
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
          }.compact

          project_data = make_request(:post, path, payload.to_json)

          Resources::Project.new(self,
                                 id: project_data["id"]&.to_i,
                                 key: project_data["key"],
                                 name: project_data["name"],
                                 adapter_source: :jira,
                                 raw_data: project_data)
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
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
