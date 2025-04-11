# frozen_string_literal: true

module ActiveProject
  module Configurations
    # Holds GitHub-specific configuration options.
    class GithubConfiguration < BaseAdapterConfiguration
      # @!attribute [rw] status_mappings
      #   @return [Hash] Mappings from GitHub issue states to ActiveProject status symbols.
      #   @example
      #     {
      #       'open' => :open,
      #       'closed' => :closed,
      #     }
      attr_accessor :status_mappings

      def initialize(options = {})
        super
        @status_mappings = options.delete(:status_mappings) || {
          "open" => :open,
          "closed" => :closed
        }
      end

      def freeze
        # Ensure nested hashes are also frozen
        @status_mappings.freeze
        super
      end
    end
  end
end