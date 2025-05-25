# frozen_string_literal: true

module ActiveProject
  module Connections
    # Relay + Link-header pagination helpers usable for REST and GraphQL
    module Pagination
      include HttpClient
      # Generic RFC-5988 “Link” header paginator (GitHub/Jira/Trello style)
      #
      # @yieldparam page [Object] parsed JSON for each HTTP page
      def each_page(path, method: :get, body: nil, query: {}, headers: {})
        next_url = path
        loop do
          page = request(method, next_url, body: body, query: query, headers: headers)
          yield page
          link_header = @last_response&.headers&.[]("Link")
          next_url = parse_link_header(link_header)["next"]
          break unless next_url

          # After first request we follow absolute URLs; zero out body/query for GETs
          body = nil if method == :get
          query = {}
        end
      end

      # Relay-style paginator (pageInfo{ hasNextPage, endCursor })
      #
      # @param connection_path [Array<String>] path inside JSON to the connection node
      # @yieldparam node [Object] each edge.node yielded
      def each_edge(query:, connection_path:, variables: {}, after_key: "after")
        cursor = nil
        loop do
          vars = variables.merge(after_key => cursor)
          data = yield(vars) # caller executes GraphQL request, returns data hash
          conn = data.dig(*connection_path)
          conn["edges"].each { |edge| yield edge["node"] }
          break unless conn["pageInfo"]["hasNextPage"]

          cursor = conn["pageInfo"]["endCursor"]
        end
      end
    end
  end
end
