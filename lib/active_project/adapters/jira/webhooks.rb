# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Webhooks
        # Parses an incoming Jira webhook payload.
        # @param request_body [String] The raw JSON request body.
        # @param headers [Hash] Request headers.
        # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
        def parse_webhook(request_body, _headers = {})
          payload = begin
            JSON.parse(request_body)
          rescue StandardError
            nil
          end
          return nil unless payload.is_a?(Hash)

          event_name = payload["webhookEvent"]
          timestamp = payload["timestamp"] ? Time.at(payload["timestamp"] / 1000) : nil

          actor_data = if event_name.start_with?("comment_")
                         payload.dig("comment", "author")
          else
                         payload["user"]
          end

          issue_data = payload["issue"]
          comment_data = payload["comment"]
          changelog = payload["changelog"]

          event_type = nil
          object_kind = nil
          event_object_id = nil
          object_key = nil
          project_id = nil
          changes = nil
          object_data = nil

          case event_name
          when "jira:issue_created"
            event_type = :issue_created
            object_kind = :issue
            event_object_id = issue_data["id"]
            object_key = issue_data["key"]
            project_id = issue_data.dig("fields", "project", "id")&.to_i
          when "jira:issue_updated"
            event_type = :issue_updated
            object_kind = :issue
            event_object_id = issue_data["id"]
            object_key = issue_data["key"]
            project_id = issue_data.dig("fields", "project", "id")&.to_i
            changes = parse_changelog(changelog)
          when "comment_created"
            event_type = :comment_added
            object_kind = :comment
            event_object_id = comment_data["id"]
            object_key = nil
            project_id = issue_data.dig("fields", "project", "id")&.to_i
          when "comment_updated"
            event_type = :comment_updated
            object_kind = :comment
            event_object_id = comment_data["id"]
            object_key = nil
            project_id = issue_data.dig("fields", "project", "id")&.to_i
          else
            return nil
          end

          WebhookEvent.new(
            type: event_type,
            resource_type: object_kind,
            resource_id: event_object_id,
            project_id: project_id,
            actor: map_user_data(actor_data),
            timestamp: timestamp,
            source: webhook_type,
            data: (object_data || {}).merge(changes: changes, object_key: object_key),
            raw_data: payload
          )
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
