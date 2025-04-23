# frozen_string_literal: true

require "uri"

module ActiveProject
  module Adapters
    module Jira
      # Low-level HTTP concerns for JiraAdapter
      module Connection
        include ActiveProject::Adapters::HttpClient

        SERAPH_HEADER = "x-seraph-loginreason".freeze

        # @param config [ActiveProject::Configurations::BaseAdapterConfiguration]
        #   Must expose :site_url, :username, :api_token.
        # @raise [ArgumentError] if required keys are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
            raise ArgumentError, "JiraAdapter requires a BaseAdapterConfiguration object"
          end
          @config = config

          # --- Build an absolute base URL ------------------------------------
          raw_url  = @config.options.fetch(:site_url)
          site_url = raw_url =~ %r{\Ahttps?://}i ? raw_url.dup : +"https://#{raw_url}"
          site_url.chomp!("/")

          username  = @config.options.fetch(:username)
          api_token = @config.options.fetch(:api_token)

          build_connection(
            base_url: site_url,
            auth_middleware: ->(conn) do
              # Faraday’s built-in basic-auth helper                               :contentReference[oaicite:0]{index=0}
              conn.request :authorization, :basic, username, api_token
            end
          )
        end

        # --------------------------------------------------------------------
        # Tiny wrapper around HttpClient#request that handles Jira quirks
        # --------------------------------------------------------------------
        #
        # @param method [Symbol]  :get, :post, :put, :delete, …
        # @param path   [String]  e.g. "/rest/api/3/issue/PROJ-1"
        # @param body   [String, Hash, nil]
        # @param query  [Hash,nil] additional query-string params
        # @return [Hash, nil] parsed JSON response
        #
        # @raise [ActiveProject::AuthenticationError] if Jira signals
        #   AUTHENTICATED_FAILED via X-Seraph-LoginReason header.
        private def make_request(method, path, body = nil, query = nil)
          data = request(method, path, body: body, query: query)

          if @connection.headers[SERAPH_HEADER]&.include?("AUTHENTICATED_FAILED")
            # Jira returns 200 + this header when credentials are wrong         :contentReference[oaicite:1]{index=1}
            raise ActiveProject::AuthenticationError,
                  "Jira authentication failed (#{SERAPH_HEADER}: AUTHENTICATED_FAILED)"
          end

          data
        end
      end
    end
  end
end
