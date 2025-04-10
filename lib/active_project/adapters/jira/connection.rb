# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Jira
      module Connection
        # Initializes the Jira Adapter.
        # @param config [Configurations::BaseAdapterConfiguration] The configuration object for Jira.
        # @raise [ArgumentError] if required configuration options (:site_url, :username, :api_token) are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
            raise ArgumentError, "JiraAdapter requires a BaseAdapterConfiguration object"
          end

          @config = config

          unless @config.options[:site_url] && !@config.options[:site_url].empty? &&
                 @config.options[:username] && !@config.options[:username].empty? &&
                 @config.options[:api_token] && !@config.options[:api_token].empty?
            raise ArgumentError, "JiraAdapter configuration requires :site_url, :username, and :api_token"
          end

          @connection = initialize_connection
        end

        private

        # Initializes the Faraday connection object.
        def initialize_connection
          site_url = @config.options[:site_url].chomp("/")
          username = @config.options[:username]
          api_token = @config.options[:api_token]

          Faraday.new(url: site_url) do |conn|
            conn.request :authorization, :basic, username, api_token
            conn.request :retry
            # Important: Keep raise_error middleware *after* retry
            # conn.response :raise_error # Defer raising error to handle_faraday_error
            conn.headers["Content-Type"] = "application/json"
            conn.headers["Accept"] = "application/json"
            conn.headers["User-Agent"] = ActiveProject.user_agent
          end
        end
      end
    end
  end
end
