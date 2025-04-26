# frozen_string_literal: true

module ActiveProject
  # Handles configuration for the ActiveProject gem, including adapter settings.
  class Configuration
    attr_reader :adapter_configs
    attr_accessor :user_agent

    # Maps adapter names (symbols) to their specific configuration classes.
    # Add other adapters here when they need specific config classes.
    ADAPTER_CONFIG_CLASSES = {
      trello: Configurations::TrelloConfiguration,
      # :jira => Configurations::JiraConfiguration,
      # :basecamp => Configurations::BasecampConfiguration,
      github: Configurations::GithubConfiguration
    }.freeze

    def initialize
      @adapter_configs = {}
      @user_agent = "ActiveProject Gem (github.com/seuros/active_project)"
    end

    # Adds or updates the configuration for a specific adapter.
    # If a block is given and a specific configuration class exists for the adapter,
    # an instance of that class is yielded to the block. Otherwise, a basic
    # configuration object is created from the options hash.
    #
    # @param adapter_type [Symbol] The name of the adapter (e.g., :basecamp, :jira, :trello).
    # @param instance_name [Symbol, Hash] The name of the adapter instance (default: :primary) or options hash.
    # @param options [Hash] Configuration options for the adapter (e.g., site, api_key, token).
    # @yield [BaseAdapterConfiguration] Yields an adapter-specific configuration object if a block is given.
    def add_adapter(adapter_type, instance_name = :primary, options = {}, &block)
      raise ArgumentError, "Adapter type must be a Symbol (e.g., :basecamp)" unless adapter_type.is_a?(Symbol)

      # Handle the case where instance_name is actually the options hash
      if instance_name.is_a?(Hash) && options.empty?
        options = instance_name
        instance_name = :primary
      end

      key = "#{adapter_type}_#{instance_name}".to_sym

      config_class = ADAPTER_CONFIG_CLASSES[adapter_type]

      if block && config_class
        adapter_config_obj = config_class.new(options)
        yield adapter_config_obj
        @adapter_configs[key] = adapter_config_obj.freeze
      elsif config_class
        adapter_config_obj = config_class.new(options)
        @adapter_configs[key] = adapter_config_obj.freeze
      else
        @adapter_configs[key] = Configurations::BaseAdapterConfiguration.new(options).freeze
      end
    end

    # Retrieves the configuration object for a specific adapter.
    # @param adapter_type [Symbol] The name of the adapter (e.g., :jira, :trello).
    # @param instance_name [Symbol] The name of the adapter instance (default: :primary).
    # @return [BaseAdapterConfiguration, nil] The configuration object or nil if not found.
    def adapter_config(adapter_type, instance_name = :primary)
      key = "#{adapter_type}_#{instance_name}".to_sym
      @adapter_configs[key]
    end
  end
end
