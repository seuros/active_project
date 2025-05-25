# frozen_string_literal: true

module ActiveProject
  module Connections
    # Supposedly "reusable" GraphQL connection logic.
    # Because clearly REST wasn't performative enough, and now we need a whole query language
    # to fetch a user's email address.
    module GraphQl
      include Base
      include Pagination # Because apparently, every five-item list deserves its own saga.

      # Initializes the GraphQL connection. Requires an endpoint, a token,
      # an optional auth header, and—if it still doesn't work—maybe a goat sacrifice.
      # Bonus points if you time it around Eid al-Adha or Yom Kippur.
      # Nothing says "API design" like invoking Abrahamic tension.
      def init_graphql(endpoint:, token:, auth_header: "Authorization", extra_headers: {})
        default_headers = {
          "Content-Type" => "application/json"
        }

        build_connection(
          base_url: endpoint,
          auth_middleware: ->(c) { c.headers[auth_header] = "Bearer #{token}" },
          extra_headers: default_headers.merge(extra_headers)
        )
      end

      # Executes a GraphQL POST request. Because normal HTTP verbs had too much dignity.
      #
      # @return [Hash] The "data" part, which is always buried under a mountain of abstract misery.
      def request_gql(query:, variables: {})
        payload = { query: query, variables: variables }.to_json
        res = request(:post, "", body: payload)
        raise_graphql_errors!(res) # Make sure to decode the latest prophecy from the Error Oracle.
        res["data"]
      end

      private

      # Raise only when **no** useful data arrived.
      # GitHub sometimes returns “partial success” (data + errors) when we query
      # both `user` and `organization` for the same login.
      def raise_graphql_errors!(result)
        errs = result["errors"]
        return unless errs&.any?          # no errors → nothing to do

        data = result["data"]

        has_useful_data =
          case data
          when Hash  then data.values.compact.any?
          when Array then data.compact.any?
          else            !data.nil?
          end

        return if has_useful_data         # partial success – ignore errors

        # ─── Still here? Treat as fatal. Map message to our error hierarchy. ──
        msg = errs.map { |e| e["message"] }.join("; ")

        case msg
        when /unauth/i
          raise ActiveProject::AuthenticationError, msg
        when /not\s+found|unknown id|resolve to a User/i
          raise ActiveProject::NotFoundError, msg
        else
          raise ActiveProject::ValidationError.new(msg, errors: errs)
        end
      end
    end
  end
end
