# frozen_string_literal: true

module ActiveProject
  module Resources
    class PersistableResource < BaseResource
      # Indicates if the resource has been persisted (typically by checking for an ID)
      def persisted?
        !id.nil? # Assumes an 'id' member
      end

      # These are now expected to be implemented by concrete subclasses
      # like Issue and Comment, or this class could provide a template
      # that calls conventionally named adapter methods.
      def save
        raise NotImplementedError, "#{self.class.name} must implement #save"
      end

      def update(attributes)
        raise NotImplementedError, "#{self.class.name} must implement #update"
      end

      def delete
        raise NotImplementedError, "#{self.class.name} must implement #delete"
      end
      alias destroy delete

      protected

      # Common logic for copying attributes after an API call
      def copy_from(other_resource)
        # Ensure it's the same type of resource before copying
        return unless other_resource.is_a?(self.class)

        self.class.members.each do |member_name|
          setter_method = "#{member_name}="
          # Check if both the current resource and the other resource can handle this member
          if respond_to?(setter_method) && other_resource.respond_to?(member_name)
            public_send(setter_method, other_resource.public_send(member_name))
          end
        end
        # Optionally, update raw_data as well if it's part of the contract
        # @raw_data = other_resource.raw_data if other_resource.respond_to?(:raw_data)
        self # Return self for chaining or assignment
      end
    end
  end
end
