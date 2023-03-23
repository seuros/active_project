# frozen_string_literal: true

require_relative "base_resource"

module ActiveProject
  module Resources
    # Represents a User
    class User < BaseResource
      def_members :id, :name, :email, :adapter_source
    end
  end
end
