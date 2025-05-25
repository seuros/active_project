# frozen_string_literal: true

module ActiveProject
  module Configurations
    class JiraConfiguration < BaseAdapterConfiguration
      # expected options:
      # :site_url   – Jira instance URL (e.g., "https://company.atlassian.net")
      # :username   – Jira username/email
      # :api_token  – Jira API token (not password)
      # optional:
      # :timeout    – Request timeout in seconds (default: 30)
      # :verify_ssl – Whether to verify SSL certificates (default: true)

      protected

      def validate_configuration!
        super # Call parent validation for retry options
        require_options(:site_url, :username, :api_token)
        validate_option_type(:site_url, String)
        validate_option_type(:username, String)
        validate_option_type(:api_token, String)
        validate_option_type(:timeout, Integer, allow_nil: true)
        validate_option_type(:verify_ssl, [ TrueClass, FalseClass ], allow_nil: true)

        # Skip format validation in test environment with dummy values
        return if test_environment_with_dummy_values?

        # Validate site_url format
        site_url = options[:site_url]
        unless site_url.match?(/^https?:\/\/.+/)
          raise ArgumentError,
                "Jira site_url must be a valid URL starting with http:// or https://, " \
                "got: #{site_url.inspect}"
        end

        # Validate username format (email or username)
        username = options[:username]
        unless username.include?("@") || username.match?(/^[a-zA-Z0-9._-]+$/)
          raise ArgumentError,
                "Jira username should be an email address or valid username, " \
                "got: #{username.inspect}"
        end

        # Validate API token format (should be base64-ish)
        api_token = options[:api_token]
        if api_token.length < 10
          raise ArgumentError,
                "Jira API token appears to be too short. Expected an API token from " \
                "Atlassian Account Settings, got token of length #{api_token.length}"
        end
      end
    end
  end
end
