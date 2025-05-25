# frozen_string_literal: true

module ActiveProject
  module Adapters
    class GithubProjectAdapter < Base
      include GithubProject::Connection
      include GithubProject::Projects
      include GithubProject::Issues
      include GithubProject::Comments
      include GithubProject::Webhooks

      def projects = ResourceFactory.new(adapter: self, resource_class: Resources::Project)
      def issues   = ResourceFactory.new(adapter: self, resource_class: Resources::Issue)

      def get_current_user
        q = "query{viewer{ id login name email }}"
        data = request_gql(query: q)
        map_user_data(data["viewer"])
      end

      def connected? = begin
        !get_current_user.nil?
      rescue StandardError
        false
      end

      private

      def map_user_data(person_data)
        return nil unless person_data && person_data["id"]

        Resources::User.new(self, # Pass adapter instance
                            id: person_data["id"],
                            name: person_data["name"],
                            email: person_data["email"],
                            adapter_source: :github_project,
                            raw_data: person_data)
      end
    end
  end
end
