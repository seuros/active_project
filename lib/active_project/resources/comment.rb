# frozen_string_literal: true

module ActiveProject
  module Resources
    # Represents a Comment on an Issue
    class Comment < PersistableResource
      def_members :id, :body, :author, :created_at, :updated_at, :issue_id,
                  :project_id, :adapter_source

      # For new comments (no id) call add_comment; otherwise update.
      def save
        fresh = if id.nil?
                  @adapter.add_comment(issue_id, body, adapter_context)
        else
                  @adapter.update_comment(id, body, adapter_context)
        end
        copy_from(fresh)
        true
      end

      # Shorthand that mutates +body+ and persists.
      def update(attrs = {})
        self.body = attrs[:body] if attrs[:body]
        save
      end

      # Remove comment remotely and freeze this instance.
      def delete
        raise "id missing – not persisted" if id.nil?

        @adapter.delete_comment(id, adapter_context)
        freeze
        true
      end

      alias destroy delete

      private

      # Build adapter-specific context for comment operations
      def adapter_context
        case @adapter
        when ActiveProject::Adapters::BasecampAdapter
          { project_id: project_id }
        when ActiveProject::Adapters::JiraAdapter
          { issue_id: issue_id }
        when ActiveProject::Adapters::TrelloAdapter
          { card_id: issue_id }
        else
          {}
        end
      end
    end
  end
end
