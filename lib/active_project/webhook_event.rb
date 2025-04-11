# frozen_string_literal: true

module ActiveProject
  # Represents a standardized event parsed from a webhook payload.
  # Using Struct for simplicity for now. Could be a full class inheriting BaseResource if needed.
  WebhookEvent = Struct.new(
    :source,          # Symbol representing the source adapter (e.g., :github, :jira, :trello)
    :type,            # Symbol representing the event type (e.g., :issue_created, :comment_added)
    :resource_type,   # Symbol representing the type of resource involved (e.g., :issue, :comment)
    :resource_id,     # String ID of the primary resource 
    :project_id,      # String ID of the associated project/repository
    :actor,           # User resource representing the user who triggered the event (optional)
    :timestamp,       # Time object representing when the event occurred (optional)
    :data,            # Hash containing event-specific data (e.g., issue, comment, changes)
    :raw_data,        # The original, parsed webhook payload hash (optional)
    keyword_init: true
  ) do
    # For backward compatibility
    alias_method :event_type, :type
    alias_method :object_kind, :resource_type
    alias_method :event_object_id, :resource_id
    alias_method :adapter_source, :source
    alias_method :object_data, :data
    
    # Helper method to get the resource object
    def resource
      return data[resource_type] if data && data.key?(resource_type)
      nil
    end
  end
end