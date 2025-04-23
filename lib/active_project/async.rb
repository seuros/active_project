# frozen_string_literal: true

module ActiveProject
  module Async
    require "async"
    require "async/http/faraday"
    def self.run(&block) = Async(&block)
  end
end
