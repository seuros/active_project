# frozen_string_literal: true

module ActiveProject
  module Resources
    # Whether it's a Jira ticket, Trello card, GitHub Issue, or Basecamp Todo
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
            adapter_update_issue(id, attrs)
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
        adapter_update_issue(ident, attributes)
        copy_from(adapter_find_issue(ident))
        true
      end

      # Delete remote record.
      def delete
        raise "project_id missing – can't destroy" unless project_id
        raise "id missing – record not persisted"  if id.nil?

        adapter_delete_issue(id)
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

      # Adapter-aware update_issue call that handles different signatures
      def adapter_update_issue(issue_id, attrs)
        case @adapter
        when ActiveProject::Adapters::BasecampAdapter
          @adapter.update_issue(issue_id, attrs, { project_id: project_id })
        when ActiveProject::Adapters::GithubProjectAdapter
          @adapter.update_issue(project_id, issue_id, attrs)
        else
          # Jira, Trello, GithubRepo: (id, attrs, context)
          @adapter.update_issue(issue_id, attrs, {})
        end
      end

      # Adapter-aware find_issue call that handles different signatures
      def adapter_find_issue(issue_id)
        case @adapter
        when ActiveProject::Adapters::BasecampAdapter
          @adapter.find_issue(issue_id, { project_id: project_id })
        else
          @adapter.find_issue(issue_id, {})
        end
      end

      # Adapter-aware delete_issue call that handles different signatures
      def adapter_delete_issue(issue_id)
        case @adapter
        when ActiveProject::Adapters::BasecampAdapter
          @adapter.delete_issue(issue_id, { project_id: project_id })
        when ActiveProject::Adapters::GithubProjectAdapter
          @adapter.delete_issue(project_id, issue_id)
        else
          # Jira, Trello, GithubRepo: (id, context)
          @adapter.delete_issue(issue_id, {})
        end
      end
    end
  end
end
