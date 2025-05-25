# frozen_string_literal: true

module ActiveProject
  module Configurations
    class GithubConfiguration < BaseAdapterConfiguration
      # expected options:
      # :access_token – PAT or GitHub App installation token
      # :owner        – user/org login the adapter should default to (optional for github_project)
      # :repo         – repository name (required for github_repo adapter)
      # optional:
      # :status_mappings – Maps GitHub project status names to normalized symbols
      #   Example: { "Todo" => :open, "In Progress" => :in_progress, "Blocked" => :blocked, "Done" => :closed }
      #   Supports: :open, :in_progress, :blocked, :on_hold, :closed
      # :webhook_secret – For webhook signature verification

      attr_accessor :status_mappings

      def initialize(options = {})
        # Set up default status mappings before calling super
        @status_mappings = options.delete(:status_mappings) || {
          "open" => :open,
          "closed" => :closed
        }
        super
      end

      def freeze
        # Ensure nested hashes are also frozen
        @status_mappings.freeze
        super
      end

      protected

      def validate_configuration!
        require_options(:access_token)
        validate_option_type(:access_token, String)
        validate_option_type(:owner, String, allow_nil: true)
        validate_option_type(:repo, String, allow_nil: true)
        validate_option_type(:webhook_secret, String, allow_nil: true)
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