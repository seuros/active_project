# frozen_string_literal: true

module ActiveProject
  # Represents a standardized event parsed from a webhook payload.
  # Using Struct for simplicity for now. Could be a full class inheriting BaseResource if needed.
  WebhookEvent = Struct.new(
    :event_type,        # Symbol representing the event (e.g., :issue_created, :comment_added)
    :object_kind,       # Symbol representing the type of object involved (e.g., :issue, :comment)
    :event_object_id,   # String or Integer ID of the primary object (renamed from object_id)
    :object_key,        # String key/slug of the primary object (if applicable, e.g., Jira issue key)
    :project_id,        # String or Integer ID of the associated project/board/bucket
    :actor,             # User resource or Hash representing the user who triggered the event
    :timestamp,         # Time object representing when the event occurred
    :adapter_source,    # Symbol identifying the source adapter (e.g., :jira, :trello, :basecamp)
    :changes,           # Hash detailing specific changes (if applicable, e.g., for updates)
    :object_data,       # Optional: Hash containing more detailed data about the object
    :raw_data,          # The original, parsed webhook payload hash
    keyword_init: true
  )
end
