# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module ActiveProject
  module Adapters
    module HttpClient
      DEFAULT_HEADERS = {
        "Content-Type" => "application/json",
        "Accept"       => "application/json",
        "User-Agent"   => -> { ActiveProject.user_agent }
      }.freeze
      RETRY_OPTS = { max: 5, interval: 0.5, backoff_factor: 2 }.freeze

      def build_connection(base_url:, auth_middleware:, extra_headers: {})
        @connection = Faraday.new(url: base_url) do |conn|
          auth_middleware.call(conn)                 # <-- adapter-specific
          conn.request  :retry, **RETRY_OPTS
          conn.response :raise_error
          conn.headers.merge!(DEFAULT_HEADERS.transform_values { |v| v.respond_to?(:call) ? v.call : v })
          conn.headers.merge!(extra_headers)
          yield conn if block_given?                 # optional extra tweaks
        end
      end

      def request(method, path, body: nil, query: nil, headers: {})
        raise "HTTP connection not initialised" unless @connection

        json_body = body.is_a?(String) ? body : (body ? JSON.generate(body) : nil)
        response  = @connection.run_request(method, path, json_body, headers) do |req|
          req.params.update(query) if query&.any?
        end

        return nil if response.status == 204 || response.body.to_s.empty?
        JSON.parse(response.body)
      rescue Faraday::Error => e
        raise translate_faraday_error(e)
      rescue JSON::ParserError => e
        raise ActiveProject::ApiError.new("Non-JSON response from #{path}",
                                          original_error: e,
                                          status_code: response&.status,
                                          response_body: response&.body)
      end

      private

      def translate_faraday_error(err)
        status = err.response_status
        body   = err.response_body.to_s
        msg    = begin JSON.parse(body)["message"] rescue body end

        case status
        when 401, 403 then ActiveProject::AuthenticationError.new(msg)
        when 404      then ActiveProject::NotFoundError.new(msg)
        when 429      then ActiveProject::RateLimitError.new(msg)
        when 400, 422 then ActiveProject::ValidationError.new(msg, status_code: status, response_body: body)
        else
          ActiveProject::ApiError.new("HTTP #{status || 'N/A'}: #{msg}",
                                      original_error: err,
                                      status_code: status,
                                      response_body: body)
        end
      end
    end
  end
end
