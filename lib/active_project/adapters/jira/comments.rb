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

        # Updates a comment on an issue in Jira using the V3 endpoint.
        # @param comment_id [String, Integer] The ID of the comment.
        # @param body [String] The new comment text.
        # @param context [Hash] Required context: { issue_id: '...' }.
        # @return [ActiveProject::Resources::Comment] The updated comment resource.
        def update_comment(comment_id, body, context = {})
          issue_id_or_key = context[:issue_id]
          unless issue_id_or_key
            raise ArgumentError,
                  "Missing required context: :issue_id must be provided for JiraAdapter#update_comment"
          end

          path = "/rest/api/3/issue/#{issue_id_or_key}/comment/#{comment_id}"

          payload = {
            body: {
              type: "doc", version: 1,
              content: [ { type: "paragraph", content: [ { type: "text", text: body } ] } ]
            }
          }.to_json

          comment_data = make_request(:put, path, payload)
          map_comment_data(comment_data, issue_id_or_key)
        end

        # Deletes a comment from an issue in Jira.
        # @param comment_id [String, Integer] The ID of the comment to delete.
        # @param context [Hash] Required context: { issue_id: '...' }.
        # @return [Boolean] True if successfully deleted.
        def delete_comment(comment_id, context = {})
          issue_id_or_key = context[:issue_id]
          unless issue_id_or_key
            raise ArgumentError,
                  "Missing required context: :issue_id must be provided for JiraAdapter#delete_comment"
          end

          path = "/rest/api/3/issue/#{issue_id_or_key}/comment/#{comment_id}"
          make_request(:delete, path)
          true
        end
      end
    end
  end
end
