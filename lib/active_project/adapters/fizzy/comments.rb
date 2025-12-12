# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Fizzy
      module Comments
        # Lists comments on a card.
        # @param card_number [Integer, String] The card number.
        # @return [Array<ActiveProject::Resources::Comment>] An array of comment resources.
        def list_comments(card_number)
          all_comments = []
          path = "cards/#{card_number}/comments.json"

          loop do
            response = @connection.get(path)
            comments_data = parse_response(response)
            break if comments_data.empty?

            comments_data.each do |comment_data|
              all_comments << map_comment_data(comment_data, card_number)
            end

            next_url = parse_next_link(response.headers["Link"])
            break unless next_url

            path = extract_path_from_url(next_url)
          end

          all_comments
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Adds a comment to a card.
        # @param card_number [Integer, String] The card number.
        # @param comment_body [String] The comment body (supports HTML rich text).
        # @param context [Hash] Optional context (not required for Fizzy).
        # @return [ActiveProject::Resources::Comment] The created comment resource.
        def add_comment(card_number, comment_body, context = {})
          path = "cards/#{card_number}/comments.json"
          payload = {
            comment: {
              body: comment_body
            }
          }

          response = @connection.post(path) do |req|
            req.body = payload.to_json
          end

          # Extract comment ID from Location header and fetch it
          location = response.headers["Location"]
          if location
            comment_id = location.match(%r{/comments/([^/.]+)})[1]
            find_comment(card_number, comment_id)
          else
            # Fallback: parse response body if available
            comment_data = parse_response(response)
            map_comment_data(comment_data, card_number)
          end
        rescue Faraday::Error => e
          handle_faraday_error(e)
        end

        # Finds a specific comment.
        # @param card_number [Integer, String] The card number.
        # @param comment_id [String] The comment ULID.
        # @return [ActiveProject::Resources::Comment] The comment resource.
        def find_comment(card_number, comment_id)
          path = "cards/#{card_number}/comments/#{comment_id}.json"
          comment_data = make_request(:get, path)
          return nil unless comment_data

          map_comment_data(comment_data, card_number)
        end

        # Updates a comment.
        # @param card_number [Integer, String] The card number.
        # @param comment_id [String] The comment ULID.
        # @param comment_body [String] The new comment body.
        # @return [ActiveProject::Resources::Comment] The updated comment resource.
        def update_comment(card_number, comment_id, comment_body)
          path = "cards/#{card_number}/comments/#{comment_id}.json"
          payload = {
            comment: {
              body: comment_body
            }
          }

          make_request(:put, path, payload.to_json)
          find_comment(card_number, comment_id)
        end

        # Deletes a comment.
        # @param card_number [Integer, String] The card number.
        # @param comment_id [String] The comment ULID.
        # @return [Boolean] True if successfully deleted.
        def delete_comment(card_number, comment_id)
          path = "cards/#{card_number}/comments/#{comment_id}.json"
          make_request(:delete, path)
          true
        end

        private

        def map_comment_data(comment_data, card_number)
          # Fizzy returns body as { plain_text: "...", html: "..." }
          body = if comment_data["body"].is_a?(Hash)
                   comment_data["body"]["plain_text"] || comment_data["body"]["html"]
                 else
                   comment_data["body"]
                 end

          Resources::Comment.new(
            self,
            id: comment_data["id"],
            body: body,
            author: map_user_data(comment_data["creator"]),
            created_at: comment_data["created_at"] ? Time.parse(comment_data["created_at"]) : nil,
            updated_at: comment_data["updated_at"] ? Time.parse(comment_data["updated_at"]) : nil,
            issue_id: card_number.to_s,
            adapter_source: :fizzy,
            raw_data: comment_data
          )
        end
      end
    end
  end
end
