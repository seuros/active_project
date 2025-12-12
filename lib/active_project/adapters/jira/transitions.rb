# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Transitions
        # Transitions a Jira issue to a new status by finding and executing the appropriate workflow transition.
        # @param issue_id_or_key [String, Integer] The ID or key of the issue.
        # @param target_status_name_or_id [String, Integer] The name or ID of the target status.
        # @param options [Hash] Optional parameters for the transition (e.g., :resolution, :comment).
        #   - :resolution [Hash] e.g., `{ name: 'Done' }`
        #   - :comment [String] Comment body to add during transition.
        # @return [Boolean] true if successful.
        # @raise [NotFoundError] if the issue or target transition is not found.
        # @raise [ApiError] for other API errors.
        def transition_issue(issue_id_or_key, target_status_name_or_id, options = {})
          transitions_path = "/rest/api/3/issue/#{issue_id_or_key}/transitions"
          begin
            response_data = make_request(:get, transitions_path)
          rescue NotFoundError
            raise NotFoundError, "Jira issue '#{issue_id_or_key}' not found."
          end
          available_transitions = response_data["transitions"] || []

          target_transition = available_transitions.find do |t|
            t["id"] == target_status_name_or_id.to_s ||
              t.dig("to", "name")&.casecmp?(target_status_name_or_id.to_s) ||
              t.dig("to", "id") == target_status_name_or_id.to_s
          end

          unless target_transition
            available_names = available_transitions.map { |t| t.dig("to", "name") }.compact.join(", ")
            raise NotFoundError,
                  "Target transition '#{target_status_name_or_id}' not found for issue " \
                  "'#{issue_id_or_key}'. Available: [#{available_names}]"
          end

          payload = {
            transition: { id: target_transition["id"] }
          }

          if options[:resolution]
            payload[:fields] ||= {}
            payload[:fields][:resolution] = options[:resolution]
          end

          if options[:comment] && !options[:comment].empty?
            payload[:update] ||= {}
            payload[:update][:comment] ||= []
            payload[:update][:comment] << {
              add: {
                body: {
                  type: "doc", version: 1,
                  content: [ { type: "paragraph", content: [ { type: "text", text: options[:comment] } ] } ]
                }
              }
            }
          end

          make_request(:post, transitions_path, payload.to_json)
          true
        rescue Faraday::Error => e
          handle_faraday_error(e)
          raise ApiError.new("Failed to transition Jira issue '#{issue_id_or_key}'", original_error: e)
        end
      end
    end
  end
end
