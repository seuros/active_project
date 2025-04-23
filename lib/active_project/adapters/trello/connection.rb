# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Connection
        include ActiveProject::Adapters::HttpClient

        BASE_URL = "https://api.trello.com/1/".freeze

        def initialize(config:)
          @config = config
          build_connection(
            base_url: BASE_URL,
            auth_middleware: ->(_c) { },           # Trello uses query-string auth
            extra_headers: { "Accept" => "application/json" }
          )
        end

        # ------------------------------------------------------------------
        # Adapter-specific wrapper around HttpClient#request
        # ------------------------------------------------------------------
        def make_request(method, path, body = nil, query_params = {})
          auth = { key: @config.api_key, token: @config.api_token }
          request(method, path,
                  body:  body,
                  query: auth.merge(query_params))
        rescue ActiveProject::ValidationError => e
          # Trello signals “resource not found / malformed id” with 400 + "invalid id"
          if e.status_code == 400 && e.message&.match?(/invalid id/i)
            raise ActiveProject::NotFoundError, e.message
          else
            raise
          end
        end

        private :make_request
      end
    end
  end
end
