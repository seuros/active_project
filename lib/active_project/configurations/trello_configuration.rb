# frozen_string_literal: true

module ActiveProject
  module Configurations
    # Holds Trello-specific configuration options.
    class TrelloConfiguration < BaseAdapterConfiguration
      # @!attribute [rw] status_mappings
      #   @return [Hash] Mappings from Board IDs to List ID/Name to Status Symbol.
      #   @example
      #     {
      #       'board_id_1' => { 'list_id_open' => :open, 'list_id_closed' => :closed },
      #       'board_id_2' => { 'Done List Name' => :closed } # Example using names (less reliable)
      #     }
      attr_accessor :status_mappings

      def initialize(options = {})
        super
        @status_mappings = options.delete(:status_mappings) || {}
      end

      def freeze
        # Ensure nested hashes are also frozen
        @status_mappings.each_value(&:freeze)
        @status_mappings.freeze
        super
      end
    end
  end
end
