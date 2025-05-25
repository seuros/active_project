# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Basecamp
      module Connection
        include Connections::Rest
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

          super(config: config)

          account_id   = @config.options.fetch(:account_id)
          access_token = @config.options.fetch(:access_token)

          init_rest(
            base_url: format(BASE_URL_TEMPLATE, account_id: account_id),
            auth_middleware: ->(conn) { conn.request :authorization, :bearer, access_token }
          )

          return if account_id && !account_id.empty? && access_token && !access_token.empty?

          raise ArgumentError, "BasecampAdapter configuration requires :account_id and :access_token"
        end
      end
    end
  end
end
