# frozen_string_literal: true

require_relative "../status_mapper"

module ActiveProject
  module Adapters
    # Base abstract class defining the interface for all adapters.
    # Concrete adapters should inherit from this class and implement its abstract methods.
    class Base
      include ErrorMapper

      # ─────────────────── Central HTTP-status → exception map ────────────
      rescue_status 401..403, with: ActiveProject::AuthenticationError
      rescue_status 404, with: ActiveProject::NotFoundError
      rescue_status 429, with: ActiveProject::RateLimitError
      rescue_status 400, 422, with: ActiveProject::ValidationError

      attr_reader :config

      def initialize(config:)
        @config = config
        @status_mapper = StatusMapper.from_config(adapter_type, config)
      end

      # Lists projects accessible by the configured credentials.
      # @return [Array<ActiveProject::Project>]
      def list_projects
        raise NotImplementedError, "#{self.class.name} must implement #list_projects"
      end

      # Finds a specific project by its ID or key.
      # @param id [String, Integer] The ID or key of the project.
      # @return [ActiveProject::Project, nil] The project object or nil if not found.
      def find_project(id)
        raise NotImplementedError, "#{self.class.name} must implement #find_project"
      end

      # Creates a new project.
      # @param attributes [Hash] Project attributes (platform-specific).
      # @return [ActiveProject::Project] The created project object.
      def create_project(attributes)
        raise NotImplementedError, "#{self.class.name} must implement #create_project"
      end

      # Creates a new list/container within a project (e.g., Trello List, Basecamp Todolist).
      # Not applicable to all platforms (e.g., Jira statuses are managed differently).
      # @param project_id [String, Integer] The ID or key of the parent project.
      # @param attributes [Hash] List attributes (platform-specific, e.g., :name).
      # @return [Hash] A hash representing the created list (platform-specific structure).
      def create_list(project_id, attributes)
        raise NotImplementedError, "#{self.class.name} does not support #create_list or must implement #create_list"
      end

      # Deletes a project. Use with caution.
      # @param project_id [String, Integer] The ID or key of the project to delete.
      # @return [Boolean] true if deletion was successful (or accepted), false otherwise.
      # @raise [NotImplementedError] if deletion is not supported or implemented.
      def delete_project(project_id)
        raise NotImplementedError, "#{self.class.name} does not support #delete_project or must implement it"
      end

      # Lists issues within a specific project.
      # @param project_id [String, Integer] The ID or key of the project.
      # @param options [Hash] Optional filtering/pagination options.
      # @return [Array<ActiveProject::Issue>]
      def list_issues(project_id, options = {})
        raise NotImplementedError, "#{self.class.name} must implement #list_issues"
      end

      # Finds a specific issue by its ID or key.
      # @param id [String, Integer] The ID or key of the issue.
      # @param context [Hash] Optional context hash. Platform-specific requirements:
      #   - Basecamp: REQUIRES { project_id: '...' }
      #   - Jira: Optional { fields: '...' }
      #   - Trello: Optional { fields: '...' }
      #   - GitHub: Ignored
      # @return [ActiveProject::Issue, nil] The issue object or nil if not found.
      # @raise [ArgumentError] if required context is missing (platform-specific).
      def find_issue(id, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #find_issue"
      end

      # Creates a new issue.
      # @param project_id [String, Integer] The ID or key of the project to create the issue in.
      # @param attributes [Hash] Issue attributes (e.g., title, description).
      # @return [ActiveProject::Issue] The created issue object.
      def create_issue(project_id, attributes)
        raise NotImplementedError, "#{self.class.name} must implement #create_issue"
      end

      # Updates an existing issue.
      # @param id [String, Integer] The ID or key of the issue to update.
      # @param attributes [Hash] Issue attributes to update.
      # @param context [Hash] Optional context hash. Platform-specific requirements:
      #   - Basecamp: REQUIRES { project_id: '...' }
      #   - Jira: Optional { fields: '...' }
      #   - Trello: Optional { fields: '...' }
      #   - GitHub: Uses different signature: update_issue(project_id, item_id, attrs)
      # @return [ActiveProject::Issue] The updated issue object.
      # @raise [ArgumentError] if required context is missing (platform-specific).
      # @note GitHub adapter overrides this with update_issue(project_id, item_id, attrs)
      #   due to GraphQL API requirements for project-specific field operations.
      def update_issue(id, attributes, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #update_issue"
      end

      # Deletes an issue from a project.
      # @param id [String, Integer] The ID or key of the issue to delete.
      # @param context [Hash] Optional context hash. Platform-specific requirements:
      #   - Basecamp: REQUIRES { project_id: '...' }
      #   - Jira: Optional { delete_subtasks: true/false }
      #   - Trello: Ignored
      #   - GitHub: Uses different signature: delete_issue(project_id, item_id)
      # @return [Boolean] true if deletion was successful.
      # @raise [ArgumentError] if required context is missing (platform-specific).
      # @note GitHub adapter overrides this with delete_issue(project_id, item_id)
      #   due to GraphQL API requirements.
      def delete_issue(id, context = {})
        raise NotImplementedError, "The #{self.class.name} adapter does not implement delete_issue"
      end

      # Adds a comment to an issue.
      # @param issue_id [String, Integer] The ID or key of the issue.
      # @param comment_body [String] The text of the comment.
      # @param context [Hash] Optional context hash. Platform-specific requirements:
      #   - Basecamp: REQUIRES { project_id: '...' }
      #   - Jira: Ignored
      #   - Trello: Ignored
      #   - GitHub: Optional { content_node_id: '...' } for optimization
      # @return [ActiveProject::Comment] The created comment object.
      # @raise [ArgumentError] if required context is missing (platform-specific).
      def add_comment(issue_id, comment_body, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #add_comment"
      end

      # Checks if the adapter supports webhook processing.
      # @return [Boolean] true if the adapter can process webhooks
      def supports_webhooks?
        respond_to?(:parse_webhook, true) &&
          !method(:parse_webhook).source_location.nil? &&
          method(:parse_webhook).source_location[0] != __FILE__
      end

      # Verifies the signature of an incoming webhook request, if supported by the platform.
      # @param request_body [String] The raw request body.
      # @param signature_header [String] The value of the platform-specific signature header.
      # @param webhook_secret [String] Optional webhook secret for verification.
      # @return [Boolean] true if the signature is valid or verification is not supported, false otherwise.
      # @note Override this method in adapter subclasses to implement platform-specific verification.
      def verify_webhook_signature(request_body, signature_header, webhook_secret: nil)
        # Default implementation assumes no verification needed.
        # Adapters supporting verification should override this method.
        supports_webhooks? # Only return true if webhooks are supported
      end

      # Parses an incoming webhook payload into a standardized WebhookEvent struct.
      # @param request_body [String] The raw request body.
      # @param headers [Hash] Optional hash of request headers (may be needed for event type detection).
      # @return [ActiveProject::WebhookEvent, nil] The parsed event object or nil if the payload is irrelevant/unparseable.
      # @raise [NotImplementedError] if webhook parsing is not implemented for the adapter.
      def parse_webhook(request_body, headers = {})
        raise NotImplementedError,
              "#{self.class.name} does not support webhook parsing. " \
              "Webhook support is optional. Check #supports_webhooks? before calling this method."
      end

      # Retrieves details for the currently authenticated user.
      # @return [ActiveProject::Resources::User] The user object.
      # @raise [ActiveProject::AuthenticationError] if authentication fails.
      # @raise [ActiveProject::ApiError] for other API-related errors.
      def get_current_user
        raise NotImplementedError, "#{self.class.name} must implement #get_current_user"
      end

      # Checks if the adapter can successfully authenticate and connect to the service.
      # Typically calls #get_current_user internally and catches authentication errors.
      # @return [Boolean] true if connection is successful, false otherwise.
      def connected?
        raise NotImplementedError, "#{self.class.name} must implement #connected?"
      end

      # Adapters that do **not** support a custom “status” field can simply rely
      # on this default implementation.  Adapters that _do_ care (e.g. the
      # GitHub project adapter which knows its single-select options) already
      # override it.
      #
      # @return [Boolean] _true_ if the symbol is safe to pass through.
      def status_known?(project_id, status_sym)
        @status_mapper.status_known?(status_sym, project_id: project_id)
      end

      # Returns all valid statuses for the given project context.
      # @param project_id [String, Integer] The project context
      # @return [Array<Symbol>] Array of valid status symbols
      def valid_statuses(project_id = nil)
        @status_mapper.valid_statuses(project_id: project_id)
      end

      # Normalizes a platform-specific status to a standard symbol.
      # @param platform_status [String, Symbol] Platform-specific status
      # @param project_id [String, Integer] Optional project context
      # @return [Symbol] Normalized status symbol
      def normalize_status(platform_status, project_id: nil)
        @status_mapper.normalize_status(platform_status, project_id: project_id)
      end

      # Converts a normalized status back to platform-specific format.
      # @param normalized_status [Symbol] Normalized status symbol
      # @param project_id [String, Integer] Optional project context
      # @return [String, Symbol] Platform-specific status
      def denormalize_status(normalized_status, project_id: nil)
        @status_mapper.denormalize_status(normalized_status, project_id: project_id)
      end

      protected

      # Returns the adapter type symbol for status mapping.
      # Override in subclasses if the adapter type differs from class name pattern.
      # @return [Symbol] The adapter type
      def adapter_type
        self.class.name.split("::").last.gsub("Adapter", "").downcase.to_sym
      end
    end
  end
end
