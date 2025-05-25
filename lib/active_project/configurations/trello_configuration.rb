# frozen_string_literal: true

module ActiveProject
  module Configurations
    # Holds Trello-specific configuration options.
    class TrelloConfiguration < BaseAdapterConfiguration
      # @!attribute [rw] status_mappings
      #   @return [Hash] Mappings from Board IDs to List ID/Name to Status Symbol.
      #   Supports expanded status vocabulary: :open, :in_progress, :blocked, :on_hold, :closed
      #   @example
      #     {
      #       'board_id_1' => {
      #         'list_id_backlog' => :open,
      #         'list_id_progress' => :in_progress,
      #         'list_id_blocked' => :blocked,
      #         'list_id_done' => :closed
      #       },
      #       'board_id_2' => { 'Done List Name' => :closed } # Using names (less reliable)
      #     }
      attr_accessor :status_mappings

      def initialize(options = {})
        super
        @status_mappings = options.delete(:status_mappings) || {}
      end

      protected

      def validate_configuration!
        require_options(:key, :token)
        validate_option_type(:key, String)
        validate_option_type(:token, String)
        validate_option_type(:status_mappings, Hash, allow_nil: true) if options[:status_mappings]

        # Skip format validation in test environment with dummy values
        nil if test_environment_with_dummy_values?

        # Additional validation for actual tokens could go here
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
