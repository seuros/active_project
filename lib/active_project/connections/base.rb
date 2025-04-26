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
        return {} unless header # Always a good first step: check if we’ve been given absolutely nothing.

        header.split(",").each_with_object({}) do |part, acc|
          url, rel = part.split(";", 2)
          next unless url && rel

          url = url[/<([^>]+)>/, 1] # Pull the sacred URL from its <> temple.
          rel = rel[/rel="?([^";]+)"?/, 1] # Decode the rel tag, likely “next,” “prev,” or “you tried.”
          acc[rel] = url if url && rel
        end
      end
    end
  end
end
