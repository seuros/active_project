# frozen_string_literal: true

module ActiveProject
  module Resources
    # Represents a Comment on an Issue
    class Comment < BaseResource
      def_members :id, :body, :author, :created_at, :updated_at, :issue_id,
                  :adapter_source
    end
  end
end
