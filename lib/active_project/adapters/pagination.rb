# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Pagination
      # RFC 5988 Link header parsing. Returns { "next" => url, "prev" => url, … }
      def parse_link_header(link_header)
        return {} unless link_header

        link_header.split(",").each_with_object({}) do |part, acc|
          url, rel = part.split(";")
          next unless rel && url

          url = url[/\<([^>]+)\>/, 1]  # strip angle brackets
          rel = rel[/rel=\"?([^\";]+)\"?/, 1]
          acc[rel] = url if url && rel
        end
      end

      # Synchronous enumerator – works with any Faraday adapter.
      #
      # @param path   [String] first request path or full URL
      # @param method [Symbol] :get or :post
      # @param body   [Hash,String,nil]
      # @param query  [Hash]
      def each_page(path, method: :get, body: nil, query: {})
        next_path = path
        loop do
          data, link_header = perform_page_request(method, next_path, body, query)
          yield data
          next_path = parse_link_header(link_header)["next"]
          break unless next_path
          # After the first hop the URL is absolute; zero-out body/query for GETs
          body = nil if method == :get
          query = {}
        end
      end

      # Fibre-friendly variant; launches a child task for every hop _after_ the
      # first one, so JSON parsing in the current page overlaps the download of
      # the next page (requires AP_DEFAULT_ADAPTER=async_http + Async scheduler).
      def each_page_async(path, method: :get, body: nil, query: {}, &block)
        require "async"       # soft-require so callers don’t need Async unless used
        Async do |task|
          current_path = path
          while current_path
            data, link = perform_page_request(method, current_path, body, query)
            next_url = parse_link_header(link)["next"]
            body = nil if method == :get # as above
            query = {}
            # Prefetch next page while the caller consumes this one
            fut = next_url ? task.async { perform_page_request(method, next_url, body, query) } : nil
            yield data
            current_path, data, link = next_url, *fut&.wait
          end
        end
      end

      private

      # One tiny helper so the logic is not duplicated.
      def perform_page_request(method, path, body, query)
        json = request(method, path, body: body, query: query)
        [ json, @last_response.headers["Link"] ]
      end
    end
  end
end
