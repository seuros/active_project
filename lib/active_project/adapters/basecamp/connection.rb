# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Connection
        include ActiveProject::Adapters::HttpClient
        BASE_URL_TEMPLATE = "https://3.basecampapi.com/%<account_id>s/"
        # Initializes the Basecamp Adapter.
        # @param config [Configurations::BaseAdapterConfiguration] The configuration object for Basecamp.
        # @raise [ArgumentError] if required configuration options (:account_id, :access_token) are missing.
        def initialize(config:)
          # For now, Basecamp uses the base config. If specific Basecamp options are added,
          # create BasecampConfiguration and check for that type.
          unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
            raise ArgumentError, "BasecampAdapter requires a BaseAdapterConfiguration object"
          end
          @config = config

          account_id   = @config.options.fetch(:account_id)
          access_token = @config.options.fetch(:access_token)

          build_connection(
            base_url: format(BASE_URL_TEMPLATE, account_id: account_id),
            auth_middleware: ->(conn) { conn.request :authorization, :bearer, access_token }
          )

          unless account_id && !account_id.empty? && access_token && !access_token.empty?
            raise ArgumentError, "BasecampAdapter configuration requires :account_id and :access_token"
          end

          @base_url = format(BASE_URL_TEMPLATE, account_id: account_id)
          @connection = initialize_connection
        end

        private

        # Initializes the Faraday connection object.
        def initialize_connection
          access_token = @config.options[:access_token]

          Faraday.new(url: @base_url) do |conn|
            conn.request :authorization, :bearer, access_token
            conn.request :retry
            conn.response :raise_error
            conn.headers["Content-Type"] = "application/json"
            conn.headers["Accept"] = "application/json"
            conn.headers["User-Agent"] = ActiveProject.user_agent
          end
        end
      end
    end
  end
end
