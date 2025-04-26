# frozen_string_literal: true

module ActiveProject
  module Configurations
    class GithubConfiguration < BaseAdapterConfiguration
      # expected options:
      # :access_token – PAT or GitHub App installation token
      # :owner        – user/org login the adapter should default to
      # optional:
      # :status_mappings – { "Todo" => :open, "In Progress" => :in_progress, "Done" => :closed }
    end
  end
end
