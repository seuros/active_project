# frozen_string_literal: true

module ActiveProject
  # Handles configuration for the ActiveProject gem, including adapter settings.
  class Configuration
    attr_reader :adapter_configs
    attr_accessor :user_agent

    # Maps adapter names (symbols) to their specific configuration classes.
    # Add other adapters here when they need specific config classes.
    ADAPTER_CONFIG_CLASSES = {
      trello: Configurations::TrelloConfiguration
      # :jira => Configurations::JiraConfiguration,
      # :basecamp => Configurations::BasecampConfiguration,
    }.freeze

    def initialize
      @adapter_configs = {}
    end
      @user_agent = "ActiveProject Gem (github.com/seuros/active_project)"

    # Adds or updates the configuration for a specific adapter.
    # If a block is given and a specific configuration class exists for the adapter,
    # an instance of that class is yielded to the block. Otherwise, a basic
    # configuration object is created from the options hash.
    #
    # @param name [Symbol] The name of the adapter (e.g., :jira, :trello).
    # @param options [Hash] Configuration options for the adapter (e.g., site, api_key, token).
    # @yield [BaseAdapterConfiguration] Yields an adapter-specific configuration object if a block is given.
    def add_adapter(name, options = {}, &block)
      unless name.is_a?(Symbol)
        raise ArgumentError, "Adapter name must be a Symbol (e.g., :jira)"
      end

      config_class = ADAPTER_CONFIG_CLASSES[name]

      # Use specific config class if block is given and class exists
      if block && config_class
        adapter_config_obj = config_class.new(options)
        yield adapter_config_obj # Allow block to modify the specific config object
        @adapter_configs[name] = adapter_config_obj.freeze
      # Use specific config class if no block but class exists (handles options like status_mappings passed directly)
      elsif config_class
         adapter_config_obj = config_class.new(options)
         @adapter_configs[name] = adapter_config_obj.freeze
      # Fallback to base config class if no specific class or no block
      else
        @adapter_configs[name] = Configurations::BaseAdapterConfiguration.new(options).freeze
      end
    end

    # Retrieves the configuration object for a specific adapter.
    # @param name [Symbol] The name of the adapter.
    # @return [BaseAdapterConfiguration, nil] The configuration object or nil if not found.
    def adapter_config(name)
      @adapter_configs[name]
    end
  end
end
