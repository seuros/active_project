# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubRepo
      module Connection
        BASE_URL = "https://api.github.com"

        # Initializes the GitHub Repo Adapter.
        # @param config [Configurations::BaseAdapterConfiguration, Configurations::GithubConfiguration]
        #        The configuration object for GitHub.
        # @raise [ArgumentError] if required configuration options (:owner, :repo, :access_token) are missing.
        def initialize(config:)
          unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
            raise ArgumentError, "GithubRepoAdapter requires a BaseAdapterConfiguration object"
          end

          @config = config

          # Extract required configuration parameters
          owner = @config.options[:owner]
          repo = @config.options[:repo]
          access_token = @config.options[:access_token]

          # Validate required configuration parameters
          unless owner && !owner.empty?
            raise ArgumentError, "GithubRepoAdapter configuration requires :owner"
          end

          unless repo && !repo.empty?
            raise ArgumentError, "GithubRepoAdapter configuration requires :repo"
          end

          unless access_token && !access_token.empty?
            raise ArgumentError, "GithubRepoAdapter configuration requires :access_token"
          end

          # Set repository path for API requests
          @repo_path = "repos/#{owner}/#{repo}"
          @connection = initialize_connection
        end

        private

        # Initializes the Faraday connection object.
        # @return [Faraday::Connection] Configured Faraday connection for GitHub API
        def initialize_connection
          access_token = @config.options[:access_token]

          Faraday.new(url: BASE_URL) do |conn|
            conn.request :authorization, :bearer, access_token
            conn.request :retry
            conn.headers["Accept"] = "application/vnd.github.v3+json"
            conn.headers["Content-Type"] = "application/json"
            conn.headers["User-Agent"] = ActiveProject.user_agent
            conn.response :raise_error
          end
        end
      end
    end
  end
end
