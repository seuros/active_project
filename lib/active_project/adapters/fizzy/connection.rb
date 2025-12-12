# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Fizzy
      module Connection
        include Connections::Rest

        DEFAULT_BASE_URL = "https://app.fizzy.do"

        # Initializes the Fizzy Adapter.
        # @param config [Configurations::FizzyConfiguration] The configuration object for Fizzy.
        # @raise [ArgumentError] if required configuration options are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::FizzyConfiguration)
            raise ArgumentError, "FizzyAdapter requires a FizzyConfiguration object"
          end

          super(config: config)

          account_slug = @config.options.fetch(:account_slug)
          access_token = @config.options.fetch(:access_token)
          base_url = @config.options[:base_url] || DEFAULT_BASE_URL

          # Fizzy uses account_slug in URL path: /:account_slug/boards, etc.
          @base_url = "#{base_url}/#{account_slug}/"

          init_rest(
            base_url: @base_url,
            auth_middleware: ->(conn) { conn.request :authorization, "Bearer", access_token },
            extra_headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
          )

          return if account_slug && !account_slug.to_s.empty? && access_token && !access_token.empty?

          raise ArgumentError, "FizzyAdapter configuration requires :account_slug and :access_token"
        end
      end
    end
  end
end
