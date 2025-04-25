# frozen_string_literal: true

module ActiveProject
  module Connections
    # Supposedly "reusable" GraphQL connection logic.
    # Because clearly REST wasn't performative enough, and now we need a whole query language
    # to fetch a user's email address.
    module GraphQl
      include Base
      include Pagination  # Because apparently, every five-item list deserves its own saga.

      # Initializes the GraphQL connection. Requires an endpoint, a token,
      # an optional auth header, and—if it still doesn't work—maybe a goat sacrifice.
      # Bonus points if you time it around Eid al-Adha or Yom Kippur.
      # Nothing says "API design" like invoking Abrahamic tension.
      def init_graphql(endpoint:, token:, auth_header: "Authorization")
        build_connection(
          base_url: endpoint,
          auth_middleware: ->(c) { c.headers[auth_header] = "Bearer #{token}" },  # Because "Bearer" is short for "Bear responsibility for this mess."
          extra_headers: { "Content-Type" => "application/json" }  # Of course it's JSON. The one part we *didn't* reinvent.
        )
      end

      # Executes a GraphQL POST request. Because normal HTTP verbs had too much dignity.
      #
      # @return [Hash] The "data" part, which is always buried under a mountain of abstract misery.
      def request_gql(query:, variables: {})
        payload = { query: query, variables: variables }.to_json
        res     = request(:post, "", body: payload)
        raise_graphql_errors!(res)  # Make sure to decode the latest prophecy from the Error Oracle.
        res["data"]
      end

      private

      # Reads GraphQL's emotional breakdown and turns it into exceptions.
      def raise_graphql_errors!(result)
        errs = result["errors"]
        return unless errs&.any?

        # Combine all the cryptic complaints into one helpful panic attack.
        msg  = errs.map { |e| e["message"] }.join("; ")

        case msg
        when /unauth/i
          raise ActiveProject::AuthenticationError, msg  # Because you're authenticated... just not enough.
        when /not\s+found|unknown id/i
          raise ActiveProject::NotFoundError, msg  # Either it doesn't exist or you made it up. Who can say.
        else
          raise ActiveProject::ValidationError.new(msg, errors: errs)  # Catch-all error, because your query's vibes were off.
        end
      end
    end
  end
end
