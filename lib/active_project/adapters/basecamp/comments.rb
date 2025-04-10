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
      end
    end
  end
end
