# frozen_string_literal: true

module ActiveProject
  module Configurations
    # Base class for adapter configurations, holding common options.
    class BaseAdapterConfiguration
      attr_reader :options

      def initialize(options = {})
        @options = options.dup # Duplicate to allow modification before freezing
      end

      # Allow accessing options via method calls
      def method_missing(method_name, *arguments, &block)
        if options.key?(method_name) && arguments.empty? && !block
          options[method_name]
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        options.key?(method_name) || super
      end

      def freeze
        @options.freeze
        super
      end
    end
  end
end
