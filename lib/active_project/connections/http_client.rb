# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module ActiveProject
  module Connections
    module HttpClient
      include Base
      attr_reader :connection, :last_response

      DEFAULT_HEADERS = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "User-Agent" => -> { ActiveProject.user_agent }
      }.freeze

      # Default retry configuration - can be overridden in adapter configs
      DEFAULT_RETRY_OPTS = {
        max: 3,                           # Maximum number of retries
        interval: 0.5,                    # Initial delay between retries (seconds)
        backoff_factor: 2,                # Exponential backoff multiplier
        retry_statuses: [ 429, 500, 502, 503, 504 ], # HTTP status codes to retry
        exceptions: [
          Faraday::TimeoutError,
          Faraday::ConnectionFailed,
          Faraday::SSLError
        ]
      }.freeze

      def build_connection(base_url:, auth_middleware:, extra_headers: {}, retry_options: {})
        @base_url = base_url

        # Merge custom retry options with defaults
        final_retry_opts = DEFAULT_RETRY_OPTS.merge(retry_options)

        @connection = Faraday.new(url: base_url) do |conn|
          auth_middleware.call(conn)                 # Let the adapter sprinkle its secret sauce here.
          conn.request  :retry, **final_retry_opts   # Intelligent retry with configurable options
          conn.response :raise_error                 # Yes, we want the failure loud and flaming.
          default_adapter = ENV.fetch("AP_DEFAULT_ADAPTER", "net_http").to_sym
          conn.adapter default_adapter
          conn.headers.merge!(DEFAULT_HEADERS.transform_values { |v| v.respond_to?(:call) ? v.call : v })
          conn.headers.merge!(extra_headers)         # Add your weird little header tweaks here.
          yield conn if block_given?                 # Optional: make it worse with your own block.
        end
      end

      # Sends the HTTP request like a brave little toaster.
      def request(method, path, body: nil, query: nil, headers: {})
        raise "HTTP connection not initialised" unless connection # You forgot to plug it in. Classic.

        json_body = if body.is_a?(String)
                      body
        else
                      (body ? JSON.generate(body) : nil)
        end
        response  = connection.run_request(method, path, json_body, headers) do |req|
          req.params.update(query) if query&.any?
        end

        @last_response = response

        return nil if response.status == 204 || response.body.to_s.empty?

        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise translate_http_error(e)
      rescue JSON::ParserError => e
        raise ActiveProject::ApiError.new("Non-JSON response from #{path}",
                                          original_error: e,
                                          status_code: response&.status,
                                          response_body: response&.body)
      end
    end
  end
end
