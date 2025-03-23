# frozen_string_literal: true

module ActiveProject
  module Adapters
    # Base abstract class defining the interface for all adapters.
    # Concrete adapters should inherit from this class and implement its abstract methods.
    class Base
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
      # @param context [Hash] Optional context hash (e.g., { project_id: '...' } for Basecamp).
      # @return [ActiveProject::Issue, nil] The issue object or nil if not found.
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
      # @param context [Hash] Optional context hash (e.g., { project_id: '...' } for Basecamp).
      # @return [ActiveProject::Issue] The updated issue object.
      def update_issue(id, attributes, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #update_issue"
      end

      # Adds a comment to an issue.
      # @param issue_id [String, Integer] The ID or key of the issue.
      # @param comment_body [String] The text of the comment.
      # @param context [Hash] Optional context hash (e.g., { project_id: '...' } for Basecamp).
      # @return [ActiveProject::Comment] The created comment object.
      def add_comment(issue_id, comment_body, context = {})
        raise NotImplementedError, "#{self.class.name} must implement #add_comment"
      end

      # Verifies the signature of an incoming webhook request, if supported by the platform.
      # @param request_body [String] The raw request body.
      # @param signature_header [String] The value of the platform-specific signature header (e.g., 'X-Trello-Webhook').
      # @return [Boolean] true if the signature is valid or verification is not supported/needed, false otherwise.
      # @raise [NotImplementedError] if verification is applicable but not implemented by a subclass.
      def verify_webhook_signature(request_body, signature_header)
        # Default implementation assumes no verification needed or supported.
        # Adapters supporting verification should override this.
        true
      end

      # Parses an incoming webhook payload into a standardized WebhookEvent struct.
      # @param request_body [String] The raw request body.
      # @param headers [Hash] Optional hash of request headers (may be needed for event type detection).
      # @return [ActiveProject::WebhookEvent, nil] The parsed event object or nil if the payload is irrelevant/unparseable.
      # @raise [NotImplementedError] if webhook parsing is not implemented for the adapter.
      def parse_webhook(request_body, headers = {})
        raise NotImplementedError, "#{self.class.name} must implement #parse_webhook"
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
    end
  end
end
