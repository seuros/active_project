# frozen_string_literal: true

module ActiveProject
  module Resources
    # Represents a Project (e.g., Jira Project, Trello Board, Basecamp Project)
    class Project < BaseResource
      def_members :id, :key, :name, :adapter_source
      # raw_data and adapter are inherited from BaseResource


      # Returns an association proxy for accessing issues within this project.
      # @return [AssociationProxy<Resources::Issue>]
      def issues
        AssociationProxy.new(owner: self, adapter: @adapter, association_name: :issues)
      end
    end
  end
end
