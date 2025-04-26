# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubProject
      module Connection
        include Connections::GraphQl

        ENDPOINT = "https://api.github.com/graphql"

        def initialize(config:)
          @config = config
          token = @config.options.fetch(:access_token)

          init_graphql(
            endpoint: ENDPOINT,
            token: token,
            extra_headers: {
              "X-Github-Next-Global-ID" => "1"
            }
          )

          # monkey-patch method for this instance only
          class << self
            prepend InstanceGraphqlPatcher
          end
        end

        module InstanceGraphqlPatcher
          def request_gql(query:, variables: {})
            payload = { query: query, variables: variables }.to_json
            res = request(:post, "", body: payload)
            handle_deprecation_warnings!(res)
            raise_graphql_errors!(res)
            res["data"]
          end

          def handle_deprecation_warnings!(res)
            warnings = res.dig("extensions", "warnings") || []
            warnings.each do |w|
              next unless w["type"] == "DEPRECATION"

              legacy = w.dig("data", "legacy_global_id")
              updated = w.dig("data", "next_global_id")
              next unless legacy && updated

              (@_deprecation_map ||= {})[legacy] = updated
            end
          end

          def upgraded_id(legacy_id)
            @_deprecation_map&.fetch(legacy_id, legacy_id)
          end
        end
      end
    end
  end
end
