# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Webhooks
        # Parses an incoming Basecamp webhook payload.
        # @param request_body [String] The raw JSON request body.
        # @param headers [Hash] Request headers (unused).
        # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
        def parse_webhook(request_body, _headers = {})
          payload = begin
            JSON.parse(request_body)
          rescue StandardError
            nil
          end
          return nil unless payload.is_a?(Hash)

          kind = payload["kind"]
          recording = payload["recording"]
          creator = payload["creator"]
          timestamp = begin
            Time.parse(payload["created_at"])
          rescue StandardError
            nil
          end
          return nil unless recording && kind

          event_type = nil
          object_kind = nil
          event_object_id = recording["id"]
          object_key = nil
          project_id = recording.dig("bucket", "id")
          changes = nil
          object_data = nil

          case kind
          when /todo_created$/
            event_type = :issue_created
            object_kind = :issue
          when /todo_assignment_changed$/, /todo_completion_changed$/, /todo_content_updated$/, /todo_description_changed$/, /todo_due_on_changed$/
            event_type = :issue_updated
            object_kind = :issue
          when /comment_created$/
            event_type = :comment_added
            object_kind = :comment
          when /comment_content_changed$/
            event_type = :comment_updated
            object_kind = :comment
          else
            return nil
          end

          WebhookEvent.new(
            event_type: event_type,
            object_kind: object_kind,
            event_object_id: event_object_id,
            object_key: object_key,
            project_id: project_id,
            actor: map_user_data(creator),
            timestamp: timestamp,
            adapter_source: :basecamp,
            changes: changes,
            object_data: object_data,
            raw_data: payload
          )
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
