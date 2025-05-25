# frozen_string_literal: true

require "openssl"
require "json"

module ActiveProject
  module Adapters
    module GithubProject
      # GitHub Project webhook processing for GitHub Projects V2.
      # Handles project item and project events from GitHub webhooks.
      module Webhooks
        # Verifies GitHub webhook signature using SHA256 HMAC.
        # @param request_body [String] Raw request body
        # @param signature_header [String] Value of X-Hub-Signature-256 header
        # @param webhook_secret [String] GitHub webhook secret
        # @return [Boolean] true if signature is valid
        def verify_webhook_signature(request_body, signature_header, webhook_secret: nil)
          return false unless webhook_secret && signature_header

          # GitHub sends signature as "sha256=<hash>"
          return false unless signature_header.start_with?("sha256=")

          expected_signature = signature_header[7..-1] # Remove "sha256=" prefix
          computed_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, request_body)

          # Use secure comparison to prevent timing attacks
          secure_compare(expected_signature, computed_signature)
        end

        # Parses GitHub webhook payload into standardized WebhookEvent.
        # Supports projects_v2_item and projects_v2 events.
        # @param request_body [String] Raw JSON payload
        # @param headers [Hash] Request headers (for X-GitHub-Event)
        # @return [ActiveProject::WebhookEvent, nil] Parsed event or nil if unsupported
        def parse_webhook(request_body, headers = {})
          payload = JSON.parse(request_body)
          github_event = headers["X-GitHub-Event"] || headers["x-github-event"]

          case github_event
          when "projects_v2_item"
            parse_project_item_event(payload)
          when "projects_v2"
            parse_project_event(payload)
          else
            # Return nil for unsupported events (not an error)
            nil
          end
        rescue JSON::ParserError
          # Invalid JSON - return nil
          nil
        end

        private

        # Secure string comparison to prevent timing attacks
        def secure_compare(a, b)
          return false unless a.bytesize == b.bytesize

          l = a.unpack("C*")
          r = b.unpack("C*")

          result = 0
          l.zip(r) { |x, y| result |= x ^ y }
          result == 0
        end

        # Parses projects_v2_item events (item created, edited, deleted, etc.)
        def parse_project_item_event(payload)
          action = payload["action"]
          item = payload["projects_v2_item"]
          return nil unless item

          # Map GitHub actions to ActiveProject event types
          event_type = case action
          when "created" then "issue_created"
          when "edited" then "issue_updated"
          when "deleted" then "issue_deleted"
          when "archived" then "issue_updated"
          when "restored" then "issue_updated"
          else action # Pass through unknown actions
          end

          # Extract project info
          project = payload["projects_v2"]
          project_id = project&.dig("node_id")

          # Extract actor (sender)
          sender = payload["sender"]
          actor = map_user_data(sender) if sender

          # Build changes hash for updates
          changes = {}
          if action == "edited" && payload["changes"]
            payload["changes"].each do |field, change_data|
              changes[field] = {
                from: change_data["from"],
                to: change_data["to"]
              }
            end
          end

          # Extract content (linked issue/PR) if available
          content = item["content"]
          object_key = content&.dig("number")&.to_s
          object_data = content || item

          WebhookEvent.new(
            event_type: event_type,
            object_kind: "issue", # GitHub Project items are treated as issues
            event_object_id: item["node_id"],
            object_key: object_key,
            project_id: project_id,
            actor: actor,
            timestamp: Time.parse(payload["created_at"] || Time.now.iso8601),
            adapter_source: webhook_type,
            changes: changes,
            object_data: object_data,
            raw_data: payload
          )
        end

        # Parses projects_v2 events (project created, edited, deleted, etc.)
        def parse_project_event(payload)
          action = payload["action"]
          project = payload["projects_v2"]
          return nil unless project

          # Map GitHub actions to ActiveProject event types
          event_type = case action
          when "created" then "project_created"
          when "edited" then "project_updated"
          when "deleted" then "project_deleted"
          else action # Pass through unknown actions
          end

          # Extract actor (sender)
          sender = payload["sender"]
          actor = map_user_data(sender) if sender

          # Build changes hash for updates
          changes = {}
          if action == "edited" && payload["changes"]
            payload["changes"].each do |field, change_data|
              changes[field] = {
                from: change_data["from"],
                to: change_data["to"]
              }
            end
          end

          WebhookEvent.new(
            event_type: event_type,
            object_kind: "project",
            event_object_id: project["node_id"],
            object_key: project["number"]&.to_s,
            project_id: project["node_id"],
            actor: actor,
            timestamp: Time.parse(payload["created_at"] || Time.now.iso8601),
            adapter_source: webhook_type,
            changes: changes,
            object_data: project,
            raw_data: payload
          )
        end
      end
    end
  end
end
