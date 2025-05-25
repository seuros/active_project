# frozen_string_literal: true

module ActiveProject
  module Configurations
    class BasecampConfiguration < BaseAdapterConfiguration
      # expected options:
      # :account_id    – Basecamp account ID (numeric)
      # :access_token  – OAuth access token from Basecamp
      # optional:
      # :user_agent    – Custom user agent string
      # :timeout       – Request timeout in seconds (default: 30)

      protected

      def validate_configuration!
        require_options(:account_id, :access_token)
        validate_option_type(:access_token, String)
        validate_option_type(:user_agent, String, allow_nil: true)
        validate_option_type(:timeout, Integer, allow_nil: true)

        # Skip format validation in test environment with dummy values
        return if test_environment_with_dummy_values?

        # Validate account_id (can be string or integer, but should be numeric)
        account_id = options[:account_id]
        unless account_id.to_s.match?(/^\d+$/)
          raise ArgumentError,
                "Basecamp account_id must be numeric, got: #{account_id.inspect}. " \
                "Find your account ID in your Basecamp URL: https://3.basecamp.com/YOUR_ACCOUNT_ID/"
        end

        # Validate access_token format (Basecamp tokens are typically long)
        access_token = options[:access_token]
        if access_token.length < 20
          raise ArgumentError,
                "Basecamp access token appears to be too short. Expected an OAuth token " \
                "from Basecamp OAuth flow, got token of length #{access_token.length}"
        end
      end
    end
  end
end
