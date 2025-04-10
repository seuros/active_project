# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Trello
      module Connection
        BASE_URL = "https://api.trello.com/1/"
        # @raise [ArgumentError] if required configuration options (:api_key, :api_token) are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::TrelloConfiguration)
            raise ArgumentError, "TrelloAdapter requires a TrelloConfiguration object"
          end

          @config = config

          unless @config.api_key && !@config.api_key.empty? && @config.api_token && !@config.api_token.empty?
            raise ArgumentError, "TrelloAdapter configuration requires :api_key and :api_token"
          end

          @connection = initialize_connection
        end

        private

        # Initializes the Faraday connection object.
        def initialize_connection
          Faraday.new(url: BASE_URL) do |conn|
            conn.request :retry
            conn.headers["Accept"] = "application/json"
            conn.response :raise_error
            conn.headers["User-Agent"] = ActiveProject.user_agent
          end
        end
      end
    end
  end
end
