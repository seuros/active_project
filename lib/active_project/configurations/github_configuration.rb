# frozen_string_literal: true

module ActiveProject
  module Configurations
    class GithubConfiguration < BaseAdapterConfiguration
      # expected options:
      # :access_token – PAT or GitHub App installation token
      # :owner        – user/org login the adapter should default to
      # optional:
      # :status_mappings – Maps GitHub project status names to normalized symbols
      #   Example: { "Todo" => :open, "In Progress" => :in_progress, "Blocked" => :blocked, "Done" => :closed }
      #   Supports: :open, :in_progress, :blocked, :on_hold, :closed

      protected

      def validate_configuration!
        require_options(:access_token)
        validate_option_type(:access_token, String)
        validate_option_type(:owner, String, allow_nil: true)
        validate_option_type(:status_mappings, Hash, allow_nil: true)

        # Skip format validation in test environment with dummy values
        return if test_environment_with_dummy_values?

        # Validate access_token format (GitHub tokens start with specific prefixes)
        token = options[:access_token]
        unless token.match?(/^(gh[pousr]_|github_pat_)/i) || token.length >= 20
          raise ArgumentError,
                "GitHub access token appears to be invalid. Expected a GitHub PAT " \
                "(starting with 'ghp_', 'gho_', 'ghu_', 'ghs_', 'ghr_', or 'github_pat_') " \
                "or a token at least 20 characters long."
        end
      end
    end
  end
end
