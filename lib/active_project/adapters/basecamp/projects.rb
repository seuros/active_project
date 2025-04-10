# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Projects
        # Lists projects accessible by the configured credentials.
        # Handles pagination automatically using the Link header.
        # @return [Array<ActiveProject::Resources::Project>] An array of project resources.
        def list_projects
          all_projects = []
          path = "projects.json"

          loop do
            response = @connection.get(path)
            projects_data = begin
              JSON.parse(response.body)
            rescue StandardError
              []
            end
            break if projects_data.empty?

            projects_data.each do |project_data|
              all_projects << Resources::Project.new(self,
                                                     id: project_data["id"],
                                                     key: nil,
                                                     name: project_data["name"],
                                                     adapter_source: :basecamp,
                                                     raw_data: project_data)
            end

            link_header = response.headers["Link"]
            next_url = parse_next_link(link_header)
            break unless next_url

            path = next_url.sub(@base_url, "").sub(%r{^/}, "")
          end

          all_projects
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Finds a specific project by its ID.
        # @param project_id [String, Integer] The ID of the Basecamp project.
        # @return [ActiveProject::Resources::Project] The project resource.
        def find_project(project_id)
          path = "projects/#{project_id}.json"
          project_data = make_request(:get, path)
          return nil unless project_data

          raise NotFoundError, "Basecamp project ID #{project_id} is trashed." if project_data["status"] == "trashed"

          Resources::Project.new(self,
                                 id: project_data["id"],
                                 key: nil,
                                 name: project_data["name"],
                                 adapter_source: :basecamp,
                                 raw_data: project_data)
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

          Resources::Project.new(self,
                                 id: project_data["id"],
                                 key: nil,
                                 name: project_data["name"],
                                 adapter_source: :basecamp,
                                 raw_data: project_data)
        end

        # Recovers a trashed project in Basecamp.
        # @param project_id [String, Integer] The ID of the project to recover.
        # @return [Boolean] true if recovery was successful (API returns 204).
        def untrash_project(project_id)
          path = "projects/#{project_id}.json"
          make_request(:put, path, { "status": "active" }.to_json)
          true
        end

        # Archives (trashes) a project in Basecamp.
        # Note: Basecamp API doesn't offer permanent deletion via this endpoint.
        # @param project_id [String, Integer] The ID of the project to trash.
        # @return [Boolean] true if trashing was successful (API returns 204).
        # @raise [NotFoundError] if the project is not found.
        # @raise [AuthenticationError] if credentials lack permission.
        # @raise [ApiError] for other errors.
        def delete_project(project_id)
          path = "projects/#{project_id}.json"
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
