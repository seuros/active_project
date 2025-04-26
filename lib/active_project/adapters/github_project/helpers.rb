# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubProject
      module Helpers
        #
        # Cursor-based pagination wrapper for GraphQL connections.
        #
        # @param query [String]   the GraphQL query with $after variable
        # @param variables [Hash] initial variables (without :after)
        # @param connection_path [Array<String>] JSON path to the connection hash
        # @yield [vars] yields the variables hash for each page so caller can execute the request
        # @return [Array<Hash>] all nodes from every page
        #
        def fetch_all_pages(query, variables:, connection_path:, &request_block)
          # turn the (possibly-nil) block into something callable
          request_fn =
            request_block ||
            ->(v) { request_gql(query: query, variables: v) }

          after = nil
          nodes = []

          loop do
            data = request_fn.call(variables.merge(after: after))
            conn = data.dig(*connection_path)
            nodes.concat(conn["nodes"])
            break unless conn["pageInfo"]["hasNextPage"]

            after = conn["pageInfo"]["endCursor"]
          end

          nodes
        end

        #
        # Resolve a user/org login → GraphQL node-ID (memoised).
        #
        def owner_node_id(login)
          @owner_id_cache ||= {}
          return @owner_id_cache[login] if @owner_id_cache.key?(login)

          q = <<~GQL
            query($login:String!){
              organization(login:$login){ id }
              user(login:$login){ id }
            }
          GQL

          data = request_gql(query: q, variables: { login: login })
          id = data.dig("organization", "id") || data.dig("user", "id")
          raise ActiveProject::NotFoundError, "GitHub owner “#{login}” not found" unless id

          id = upgraded_id(id) if respond_to?(:upgraded_id)

          @owner_id_cache[login] = id
        end

        #
        # Convert a compact user hash returned by GraphQL into Resources::User.
        #
        def map_user(u)
          return nil unless u

          Resources::User.new(
            self,
            id: u["id"] || u["login"],
            name: u["login"],
            email: u["email"],
            adapter_source: :github,
            raw_data: u
          )
        end

        def project_field_ids(project_id)
          @field_cache ||= {}
          @field_cache[project_id] ||= begin
            q = <<~GQL
              query($id:ID!){
                node(id:$id){
                  ... on ProjectV2{
                    fields(first:50){
                      nodes{
                        ... on ProjectV2FieldCommon{ id name }
                      }
                    }
                  }
                }
              }
            GQL
            nodes = request_gql(query: q, variables: { id: project_id })
                    .dig("node", "fields", "nodes")
            nodes.to_h { |f| [ f["name"], f["id"] ] }
          end
        end
      end
    end
  end
end
