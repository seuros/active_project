# frozen_string_literal: true

module ActiveProject
  module Resources
    # Base class for resource objects (Project, Issue, etc.)
    # Provides common initialization and attribute access via method_missing.
    class BaseResource
      attr_reader :adapter, :raw_data, :attributes

      # @param adapter [Adapters::Base] The adapter instance that fetched/created this resource.
      # @param attributes [Hash] A hash of attributes for the resource.
      def initialize(adapter, attributes = {})
        @adapter = adapter
        # Store raw_data if provided, otherwise duplicate the input attributes
        @raw_data = attributes.key?(:raw_data) ? attributes[:raw_data] : attributes.dup
        # Store attributes for method_missing access, remove raw_data key if it exists
        @attributes = attributes.dup
        @attributes.delete(:raw_data)
      end

      # Basic inspection using defined members if available, otherwise attributes.
      def inspect
        members_to_show = self.class.members.empty? ? @attributes.keys : self.class.members
        attrs_str = members_to_show.map { |m| "#{m}=#{send(m).inspect}" }.join(", ")
        "#<#{self.class.name} #{attrs_str}>"
      end

      # Method missing for accessing attributes stored in @attributes hash.
      def method_missing(method_name, *arguments, &block)
        if @attributes.key?(method_name)
          # Return attribute value if no arguments are given (getter)
          arguments.empty? ? @attributes[method_name] : super
        else
          super
        end
      end

      # Ensure respond_to? works correctly with method_missing.
      def respond_to_missing?(method_name, include_private = false)
        @attributes.key?(method_name) || super
      end

      # Class method to define expected members (mainly for introspection/documentation).
      def self.members
        @members ||= []
      end

      # Defines expected members for the resource class.
      def self.def_members(*names)
        @members ||= []
        names.each do |name|
          sym = name.to_sym
          @members << sym
          define_method(sym) { @attributes[sym] } # reader
          define_method("#{sym}=") do |val| # writer
            @attributes[sym] = val
          end
        end
      end

      def to_h
        self.class.members.each_with_object({}) do |name, hash|
          hash[name] = public_send(name)
        end
      end
    end
  end
end
