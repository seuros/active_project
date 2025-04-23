# frozen_string_literal: true

module ActiveProject
  module Connections
    # Shared helpers used by both REST and GraphQL modules,
    # because every cult needs a doctrine of "Don't Repeat Yourself."
    module Base
      # ------------------------------------------------------------------
      # RFC 5988 Link header parsing
      # ------------------------------------------------------------------
      #
      # Parses your classic overengineered pagination headers.
      #
      #   <https://api.example.com/…?page=2>; rel="next",
      #   <https://api.example.com/…?page=5>; rel="last"
      #
      # REST’s way of pretending it’s not just guessing how many pages there are.
      #
      # @param header [String, nil]
      # @return [Hash{String => String}] map of rel => absolute URL
      def parse_link_header(header)
        return {} unless header  # Always a good first step: check if we’ve been given absolutely nothing.

        header.split(",").each_with_object({}) do |part, acc|
          url, rel = part.split(";", 2)
          next unless url && rel

          url = url[/\<([^>]+)\>/, 1]  # Pull the sacred URL from its <> temple.
          rel = rel[/rel="?([^\";]+)"?/, 1]  # Decode the rel tag, likely “next,” “prev,” or “you tried.”
          acc[rel] = url if url && rel
        end
      end

      private

      # Converts Faraday/HTTP errors into custom ActiveProject errors,
      # to reflect the spiritual disharmony between client and server.
      def map_faraday_error(err)
        status = err.response_status
        body   = err.response_body.to_s
        msg    = begin
                   JSON.parse(body)["message"]  # Attempt to extract meaning from chaos.
                 rescue StandardError
                   body  # If that fails, just channel the entire unfiltered anguish.
                 end

        case status
        when 401, 403
          ActiveProject::AuthenticationError.new(msg)  # Root chakra blocked. You’re not grounded. Or authenticated.
        when 404
          ActiveProject::NotFoundError.new(msg)  # Sacral chakra disturbance. The thing you desire does not exist. Embrace the void.
        when 429
          ActiveProject::RateLimitError.new(msg)  # Solar plexus overload. You asked too much. Sit in a quiet room and contemplate restraint.
        when 400, 422
          ActiveProject::ValidationError.new(msg, status_code: status, response_body: body)  # Heart chakra misalignment. Your intentions were pure, but malformed.
        else
          ActiveProject::ApiError.new("HTTP #{status || 'N/A'}: #{msg}",
                                      original_error: err,
                                      status_code: status,
                                      response_body: body)  # Crown chakra shattered. The cosmos has rejected your request. Seek inner peace. Or fix your payload.
        end
      end
    end
  end
end
