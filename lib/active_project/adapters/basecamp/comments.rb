# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Comments
        # Adds a comment to a To-do in Basecamp.
        # @param todo_id [String, Integer] The ID of the Basecamp To-do.
        # @param comment_body [String] The comment text (HTML).
        # @param context [Hash] Required context: { project_id: '...' }.
        # @return [ActiveProject::Resources::Comment] The created comment resource.
        def add_comment(todo_id, comment_body, context = {})
          project_id = context[:project_id]
          unless project_id
            raise ArgumentError,
                  "Missing required context: :project_id must be provided for BasecampAdapter#add_comment"
          end

          path = "buckets/#{project_id}/recordings/#{todo_id}/comments.json"
          payload = { content: comment_body }.to_json
          comment_data = make_request(:post, path, payload)
          map_comment_data(comment_data, todo_id.to_i)
        end

        # Updates a comment on a To-do in Basecamp.
        # @param comment_id [String, Integer] The ID of the comment.
        # @param body [String] The new comment text (HTML).
        # @param context [Hash] Required context: { project_id: '...' }.
        # @return [ActiveProject::Resources::Comment] The updated comment resource.
        def update_comment(comment_id, body, context = {})
          project_id = context[:project_id]
          unless project_id
            raise ArgumentError,
                  "Missing required context: :project_id must be provided for BasecampAdapter#update_comment"
          end

          path = "buckets/#{project_id}/comments/#{comment_id}.json"
          payload = { content: body }.to_json
          comment_data = make_request(:put, path, payload)
          map_comment_data(comment_data, comment_data["parent"]&.dig("id"))
        end

        # Deletes a comment from a To-do in Basecamp.
        # @param comment_id [String, Integer] The ID of the comment to delete.
        # @param context [Hash] Required context: { project_id: '...' }.
        # @return [Boolean] True if successfully deleted.
        def delete_comment(comment_id, context = {})
          project_id = context[:project_id]
          unless project_id
            raise ArgumentError,
                  "Missing required context: :project_id must be provided for BasecampAdapter#delete_comment"
          end

          path = "buckets/#{project_id}/recordings/#{comment_id}/status/trashed.json"
          make_request(:put, path)
          true
        end
      end
    end
  end
end
