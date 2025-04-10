# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Comments
        # Adds a comment to an issue in Jira using the V3 endpoint.
        # @param issue_id_or_key [String, Integer] The ID or key of the issue.
        # @param comment_body [String] The text of the comment.
        # @param context [Hash] Optional context (ignored).
        # @return [ActiveProject::Resources::Comment] The created comment resource.
        def add_comment(issue_id_or_key, comment_body, _context = {})
          path = "/rest/api/3/issue/#{issue_id_or_key}/comment"

          payload = {
            body: {
              type: "doc", version: 1,
              content: [ { type: "paragraph", content: [ { type: "text", text: comment_body } ] } ]
            }
          }.to_json

          comment_data = make_request(:post, path, payload)
          map_comment_data(comment_data, issue_id_or_key)
        end
      end
    end
  end
end
