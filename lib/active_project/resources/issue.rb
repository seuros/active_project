# frozen_string_literal: true

module ActiveProject
  module Resources
    # Whether it’s a Jira ticket, Trello card, GitHub Issue, or Basecamp Todo
    class Issue < PersistableResource
      def_members :id, :key, :title, :description, :status, :assignees,
                  :reporter, :project_id, :created_at, :updated_at, :due_on,
                  :priority, :adapter_source

      def initialize(adapter, attributes = {})
        super
        @initial_title = attributes[:title]
      end

      # Persist the record, creating it if it does not yet exist.
      def save
        unless project_id
          raise ActiveProject::NotImplementedError,
                "#save not supported on transient records"
        end

        attrs = to_h.slice(:title, :description, :status, :assignees,
                           :reporter, :due_on, :priority)

        if @adapter.is_a?(ActiveProject::Adapters::JiraAdapter)
          if id.nil? # first persist ⇒ create_issue
            attrs.delete(:title)                  # remove :title entirely
            attrs[:summary] = @initial_title      # use the ORIGINAL title
          elsif attrs.key?(:title) # later saves ⇒ update_issue
            attrs[:summary] = attrs.delete(:title)
          end
        end

        attrs.delete(:status) unless @adapter.status_known?(project_id, attrs[:status])

        fresh =
          if id.nil?
            adapter.create_issue(project_id, attrs)
          else
            adapter.update_issue(project_id, id, attrs)
          end

        copy_from(fresh)
        true
      end

      # Update attributes and persist them.
      def update(attributes = {})
        unless project_id && id
          raise ActiveProject::NotImplementedError,
                "#update not supported on transient records"
        end
        unless attributes.is_a?(Hash)
          raise ActiveProject::NotImplementedError,
                "attributes must be a Hash"
        end

        ident = key || id
        @adapter.update_issue(project_id, ident, attributes)
        copy_from(@adapter.find_issue(ident))
        true
      end

      # Delete remote record.
      def delete
        raise "project_id missing – can’t destroy" unless project_id
        raise "id missing – record not persisted"  if id.nil?

        adapter.delete_issue(project_id, id)
        freeze
        true
      end
      alias destroy delete

      # Lazy association proxy for comments.
      def comments
        AssociationProxy.new(owner: self, adapter: adapter, association_name: :comments)
      end

      private

      def copy_from(other)
        self.class.members.each { |m| public_send("#{m}=", other.public_send(m)) }
      end
    end
  end
end
