# frozen_string_literal: true

module ActiveProject
  # Handles bidirectional status mapping between platform-specific statuses
  # and normalized ActiveProject status symbols.
  #
  # Supports:
  # - Standard status symbols (:open, :in_progress, :closed, :blocked, :on_hold)
  # - Platform-specific status preservation
  # - Configurable status mappings per adapter
  # - Fallback to standard status normalization
  class StatusMapper
    # Standard ActiveProject status symbols with their meanings
    STANDARD_STATUSES = {
      open: "New, unstarted work",
      in_progress: "Currently being worked on",
      blocked: "Waiting on external dependency",
      on_hold: "Temporarily paused",
      closed: "Completed or resolved"
    }.freeze

    # Default mapping rules for common status patterns
    DEFAULT_MAPPINGS = {
      # Open/New statuses
      /^(new|open|todo|to do|backlog|ready|created)$/i => :open,

      # In Progress statuses
      /^(in progress|in_progress|active|working|started|doing)$/i => :in_progress,

      # Blocked statuses
      /^(blocked|waiting|pending|on hold|on_hold|paused)$/i => :blocked,

      # Closed statuses
      /^(done|closed|completed|finished|resolved|fixed)$/i => :closed
    }.freeze

    attr_reader :adapter_type, :custom_mappings

    # @param adapter_type [Symbol] The adapter type (:jira, :trello, etc.)
    # @param custom_mappings [Hash] Custom status mappings from configuration
    def initialize(adapter_type, custom_mappings = {})
      @adapter_type = adapter_type
      @custom_mappings = custom_mappings || {}
    end

    # Converts a platform-specific status to a normalized status symbol.
    # @param platform_status [String, Symbol] The platform-specific status
    # @param context [Hash] Optional context (e.g., project_id for project-specific mappings)
    # @return [Symbol] Normalized status symbol
    def normalize_status(platform_status, context = {})
      return platform_status if STANDARD_STATUSES.key?(platform_status.to_sym)

      # Try custom mappings first
      if custom_mappings.is_a?(Hash)
        # Support project-specific mappings (for Trello, GitHub)
        project_mappings = custom_mappings[context[:project_id]] || custom_mappings

        # Check direct mapping
        if project_mappings[platform_status.to_s]
          return project_mappings[platform_status.to_s].to_sym
        end
      end

      # Fall back to pattern matching
      status_str = platform_status.to_s.strip
      DEFAULT_MAPPINGS.each do |pattern, normalized_status|
        return normalized_status if status_str.match?(pattern)
      end

      # If no mapping found, return as symbol for platform-specific handling
      platform_status.to_s.downcase.tr(" -", "_").to_sym
    end

    # Converts a normalized status symbol back to platform-specific status.
    # @param normalized_status [Symbol] The normalized status symbol
    # @param context [Hash] Optional context for platform-specific conversion
    # @return [String, Symbol] Platform-specific status representation
    def denormalize_status(normalized_status, context = {})
      # If it's already a standard status, delegate to adapter-specific logic
      return normalized_status if STANDARD_STATUSES.key?(normalized_status.to_sym)

      # Try reverse lookup in custom mappings
      if custom_mappings.is_a?(Hash)
        project_mappings = custom_mappings[context[:project_id]] || custom_mappings

        # Find the platform status that maps to this normalized status
        project_mappings.each do |platform_status, mapped_status|
          return platform_status if mapped_status.to_sym == normalized_status.to_sym
        end
      end

      # Default: return the status as-is for platform handling
      normalized_status
    end

    # Checks if a status is known/valid for the given context.
    # @param status [Symbol, String] The status to check
    # @param context [Hash] Optional context for validation
    # @return [Boolean] true if the status is valid
    def status_known?(status, context = {})
      # Handle nil status
      return false if status.nil?

      # Standard statuses are always known
      return true if STANDARD_STATUSES.key?(status.to_sym)

      # Check custom mappings
      if custom_mappings.is_a?(Hash)
        project_mappings = custom_mappings[context[:project_id]] || custom_mappings
        return true if project_mappings.key?(status.to_s)
      end

      # Check if it matches any default patterns
      status_str = status.to_s.strip
      DEFAULT_MAPPINGS.any? { |pattern, _| status_str.match?(pattern) }
    end

    # Returns all valid statuses for the given context.
    # @param context [Hash] Optional context
    # @return [Array<Symbol>] Array of valid status symbols
    def valid_statuses(context = {})
      statuses = STANDARD_STATUSES.keys.dup

      # Add custom mapped statuses
      if custom_mappings.is_a?(Hash)
        project_mappings = custom_mappings[context[:project_id]] || custom_mappings
        project_mappings.each do |platform_status, normalized_status|
          statuses << normalized_status.to_sym
          statuses << platform_status.to_s.downcase.tr(" -", "_").to_sym
        end
      end

      statuses.uniq
    end

    # Creates a status mapper instance from adapter configuration.
    # @param adapter_type [Symbol] The adapter type
    # @param config [ActiveProject::Configurations::BaseAdapterConfiguration] Adapter config
    # @return [StatusMapper] Configured status mapper
    def self.from_config(adapter_type, config)
      status_mappings = config.respond_to?(:status_mappings) ? config.status_mappings : {}
      new(adapter_type, status_mappings)
    end
  end
end
