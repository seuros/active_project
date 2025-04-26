# frozen_string_literal: true

module ActiveProject
  module Connections
    # Reusable REST connection logic for normal, boring APIs like Jira, Basecamp, and Trello.
    # You know, ones that don’t require a decoder ring and a theological debate to use.
    module Rest
      include Base
      include Pagination

      # Must be called from the concrete adapter's initialize.
      #
      # @yieldparam conn [Faraday::Connection] A lovely, dependable object where you slap on your auth.
      # Unlike GraphQL, this one doesn’t need you to bend the knee or cite the Book of Steve Job.
      def init_rest(base_url:, auth_middleware:, extra_headers: {})
        build_connection(
          base_url: base_url,
          auth_middleware: auth_middleware,
          extra_headers: extra_headers
        )
      end

      # Wrapper around HttpClient#request.
      # Adapters may override this if their APIs have... *quirks* (read: sins).
      def request_rest(method, path, body = nil, query = nil, headers = {})
        request(method, path, body: body, query: query, headers: headers)
      rescue Faraday::Error => e
        raise map_faraday_error(e) # Wrap Faraday errors in our custom trauma response.
      end
    end
  end
end
