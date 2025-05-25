# frozen_string_literal: true

module ActiveProject
  module ErrorMapper
    extend ActiveSupport::Concern

    included do
      # one hash per subclass, inherited & copy-on-write
      class_attribute :error_map, instance_accessor: false, default: {}
    end

    class_methods do
      # rescue_status 401..403, with: AuthenticationError
      def rescue_status(*codes, with:)
        new_map = error_map.dup
        codes.flat_map { |c| c.is_a?(Range) ? c.to_a : c }
             .each { |status| new_map[status] = with }
        self.error_map = new_map.freeze
      end
    end

    private

    def translate_http_error(err)
      status  = err.response_status
      message = begin
        JSON.parse(err.response_body.to_s)["message"]
      rescue StandardError
        err.response_body
      end

      exc = self.class.error_map[status] ||
            ActiveProject::ApiError

      raise exc, message, err.backtrace
    end
  end
end
