# frozen_string_literal: true

module ActiveProject
  module Resources
    # Represents an Issue (e.g., Jira Issue, Trello Card, Basecamp Todo)
    class Issue < BaseResource
      def_members :id, :key, :title, :description, :status, :assignees,
                  :reporter, :project_id, :created_at, :updated_at, :due_on,
                  :priority, :adapter_source
      # raw_data and adapter are inherited from BaseResource


      # Saves the issue (creates if new, updates if existing).
      # Placeholder - Full implementation requires attribute tracking and adapter delegation.
      # @return [Boolean] true if save was successful, false otherwise.
      def save
        raise NotImplementedError, "#save not yet implemented for #{self.class.name}"
      end

      # Updates the issue with the given attributes and saves it.
      # Placeholder - Full implementation requires attribute tracking and adapter delegation.
      # @param attributes [Hash] Attributes to update.
      # @return [Boolean] true if update was successful, false otherwise.
      def update(attributes)
        # Basic implementation could be:
        # attributes.each { |k, v| instance_variable_set("@#{k}", v) if respond_to?(k) } # Need setters or direct ivar access
        # save
        raise NotImplementedError, "#update not yet implemented for #{self.class.name}"
      end


      # Returns an association proxy for accessing comments on this issue.
      # @return [AssociationProxy<Resources::Comment>]
      def comments
        AssociationProxy.new(owner: self, adapter: @adapter, association_name: :comments)
      end
    end
  end
end
