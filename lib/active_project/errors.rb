# frozen_string_literal: true

module ActiveProject
  # Base class for all ActiveProject errors
  class Error < StandardError; end

  # Raised when authentication with the external API fails
  class AuthenticationError < Error; end

  # Raised when a requested resource is not found
  class NotFoundError < Error; end

  # Raised when the external API rate limit is exceeded
  class RateLimitError < Error; end

  # Raised for configuration errors (e.g., missing required settings, invalid mappings)
  class ConfigurationError < Error; end

  # Raised for connection errors (e.g., network failures, timeouts)
  class ConnectionError < Error
    attr_reader :original_error

    def initialize(message = nil, original_error: nil)
      super(message)
      @original_error = original_error
    end
  end

  # Raised for general API errors (e.g., 5xx status codes)
  class ApiError < Error
    attr_reader :original_error, :status_code, :response_body

    def initialize(message = nil, original_error: nil, status_code: nil, response_body: nil)
      super(message)
      @original_error = original_error
      @status_code = status_code
      @response_body = response_body
    end
  end

  # Raised for validation errors (e.g., 400/422 status codes with field details)
  class ValidationError < ApiError
    attr_reader :errors

    def initialize(message = nil, errors: {}, original_error: nil, status_code: nil, response_body: nil)
      super(message, original_error: original_error, status_code: status_code, response_body: response_body)
      @errors = errors # Expects a hash like { field: ['message1', 'message2'] }
    end
  end

  # Raised when an adapter method is not implemented
  class NotImplementedError < Error; end
end
