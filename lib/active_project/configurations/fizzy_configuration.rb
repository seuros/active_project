# frozen_string_literal: true

module ActiveProject
  module Configurations
    # Holds Fizzy-specific configuration options.
    class FizzyConfiguration < BaseAdapterConfiguration
      # @!attribute [rw] status_mappings
      #   @return [Hash] Mappings from Board IDs to Column Name to Status Symbol.
      #   Supports expanded status vocabulary: :open, :in_progress, :blocked, :on_hold, :closed
      #   @example
      #     {
      #       'board_id_1' => {
      #         'In Progress' => :in_progress,
      #         'Blocked' => :blocked,
      #         'Done' => :closed
      #       }
      #     }
      attr_accessor :status_mappings

      def initialize(options = {})
        super
        @status_mappings = options.delete(:status_mappings) || {}
      end

      protected

      def validate_configuration!
        require_options(:account_slug, :access_token)
        validate_option_type(:account_slug, String)
        validate_option_type(:access_token, String)
        validate_option_type(:base_url, String, allow_nil: true) if options[:base_url]
        validate_option_type(:status_mappings, Hash, allow_nil: true) if options[:status_mappings]

        super # Validate retry_options if present
      end

      public

      def freeze
        # Ensure nested hashes are also frozen
        @status_mappings.each_value(&:freeze)
        @status_mappings.freeze
        super
      end
    end
  end
end
