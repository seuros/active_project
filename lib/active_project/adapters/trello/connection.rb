# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Connection
        include Connections::Rest

        BASE_URL = "https://api.trello.com/1/"

        def initialize(config:)
          super(config: config)
          init_rest(
            base_url: BASE_URL,
            auth_middleware: ->(_c) { }, # Trello uses query-string auth
            extra_headers: { "Accept" => "application/json" }
          )
        end

        # ------------------------------------------------------------------
        # Adapter-specific wrapper around HttpClient#request
        # ------------------------------------------------------------------
        def make_request(method, path, body = nil, query_params = {})
          auth = { key: @config.key, token: @config.token }
          request(method, path,
                  body: body,
                  query: auth.merge(query_params))
        rescue ActiveProject::ValidationError => e
          # Trello signals “resource not found / malformed id” with 400  "invalid id"
          invalid_id = /invalid id/i
          if (e.status_code.nil? || e.status_code == 400) &&
             (e.message&.match?(invalid_id) ||
               e.response_body.to_s.match?(invalid_id))
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
