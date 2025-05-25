# frozen_string_literal: true

require "uri"

module ActiveProject
  module Adapters
    module Jira
      # Low-level HTTP concerns for JiraAdapter
      module Connection
        include Connections::Rest

        SERAPH_HEADER = "x-seraph-loginreason"

        # @param config [ActiveProject::Configurations::BaseAdapterConfiguration]
        #   Must expose :site_url, :username, :api_token.
        # @raise [ArgumentError] if required keys are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
            raise ArgumentError, "JiraAdapter requires a BaseAdapterConfiguration object"
          end

          super(config: config)

          # --- Build an absolute base URL ------------------------------------
          raw_url = @config.options.fetch(:site_url)
          site_url = raw_url =~ %r{\Ahttps?://}i ? raw_url.dup : +"https://#{raw_url}"
          site_url.chomp!("/")

          username = @config.options.fetch(:username)
          api_token = @config.options.fetch(:api_token)

          init_rest(
            base_url: site_url,
            auth_middleware: lambda do |conn|
              # Faraday’s built-in basic-auth helper                               :contentReference[oaicite:0]{index=0}
              conn.request :authorization, :basic, username, api_token
            end
          )
        end

        private

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
        def make_request(method, path, body = nil, query = nil, headers = {})
          res = request_rest(method, path, body, query, headers)
          if last_response&.headers&.[](SERAPH_HEADER)&.include?("AUTHENTICATED_FAILED")
            raise ActiveProject::AuthenticationError, "Jira authentication failed"
          end

          res
        end
      end
    end
  end
end
