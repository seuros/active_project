# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Webhooks
        # Parses an incoming Trello webhook payload.
        # @param request_body [String] The raw JSON request body.
        # @param headers [Hash] Request headers (unused).
        # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unhandled.
        def parse_webhook(request_body, _headers = {})
          payload = begin
            JSON.parse(request_body)
          rescue StandardError
            nil
          end
          return nil unless payload.is_a?(Hash) && payload["action"].is_a?(Hash)

          action = payload["action"]
          action_type = action["type"]
          actor_data = action["memberCreator"]
          timestamp = begin
            Time.parse(action["date"])
          rescue StandardError
            nil
          end
          board_id = action.dig("data", "board", "id")
          card_data = action.dig("data", "card")
          action.dig("data", "text")
          old_data = action.dig("data", "old")

          event_type = nil
          object_kind = nil
          event_object_id = nil
          object_key = nil
          changes = nil
          object_data = nil

          case action_type
          when "createCard"
            event_type = :issue_created
            object_kind = :issue
            event_object_id = card_data["id"]
            object_key = card_data["idShort"]
          when "updateCard"
            event_type = :issue_updated
            object_kind = :issue
            event_object_id = card_data["id"]
            object_key = card_data["idShort"]
            if old_data.is_a?(Hash)
              changes = {}
              old_data.each do |field, old_value|
                new_value = card_data[field]
                changes[field.to_sym] = [ old_value, new_value ]
              end
            end
          when "commentCard"
            event_type = :comment_added
            object_kind = :comment
            event_object_id = action["id"]
            object_key = nil
          when "addMemberToCard", "removeMemberFromCard"
            event_type = :issue_updated
            object_kind = :issue
            event_object_id = card_data["id"]
            object_key = card_data["idShort"]
            changes = { assignees: true }
          else
            return nil
          end

          WebhookEvent.new(
            event_type: event_type,
            object_kind: object_kind,
            event_object_id: event_object_id,
            object_key: object_key,
            project_id: board_id,
            actor: map_user_data(actor_data),
            timestamp: timestamp,
            adapter_source: :trello,
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
