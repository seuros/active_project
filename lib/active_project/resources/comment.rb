# frozen_string_literal: true

module ActiveProject
  module Resources
    # Represents a Comment on an Issue
    class Comment < PersistableResource
      def_members :id, :body, :author, :created_at, :updated_at, :issue_id,
                  :adapter_source

      # For new comments (no id) call add_comment; otherwise update.
      def save
        fresh = if id.nil?
                  @adapter.add_comment(issue_id, body, content_node_id: nil)
        else
                  @adapter.update_comment(id, body)
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

        @adapter.delete_comment(id)
        freeze
        true
      end

      alias destroy delete
    end
  end
end
