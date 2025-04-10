# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Lists
        # Creates a new Todolist within a project.
        # @param project_id [String, Integer] The ID of the Basecamp project (bucket).
        # @param attributes [Hash] Todolist attributes. Required: :name. Optional: :description.
        # @return [Hash] The raw data hash of the created todolist.
        def create_list(project_id, attributes)
          unless attributes[:name] && !attributes[:name].empty?
            raise ArgumentError, "Missing required attribute for Basecamp todolist creation: :name"
          end

          project_data = make_request(:get, "projects/#{project_id}.json")
          todoset_dock_entry = project_data&.dig("dock")&.find { |d| d["name"] == "todoset" }
          todoset_url = todoset_dock_entry&.dig("url")
          raise ApiError, "Could not find todoset URL for project #{project_id}" unless todoset_url

          todoset_id = todoset_url.match(%r{todosets/(\d+)\.json$})&.captures&.first
          raise ApiError, "Could not extract todoset ID from URL: #{todoset_url}" unless todoset_id

          path = "buckets/#{project_id}/todosets/#{todoset_id}/todolists.json"
          payload = {
            name: attributes[:name],
            description: attributes[:description]
          }.compact

          make_request(:post, path, payload.to_json)
        end

        # Finds the ID of the first todolist in a project.
        # @param project_id [String, Integer]
        # @return [String, nil]
        def find_first_todolist_id(project_id)
          project_data = make_request(:get, "projects/#{project_id}.json")
          todoset_dock_entry = project_data&.dig("dock")&.find { |d| d["name"] == "todoset" }
          todoset_url = todoset_dock_entry&.dig("url")
          return nil unless todoset_url

          todoset_id = todoset_url.match(%r{todosets/(\d+)\.json$})&.captures&.first
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
end
