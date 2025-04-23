require "zeitwerk"
require "concurrent"
require_relative "active_project/errors"
require_relative "active_project/version"
require_relative "active_project/railtie" if defined?(Rails::Railtie)

module ActiveProject
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Resets all cached adapters, forcing them to be re-initialized with current configuration
    # @return [void]
    def reset_adapters
      adapter_registry.clear if defined?(@adapter_registry) && @adapter_registry
    end

    # Returns the configured User-Agent string, including the gem version.
    # @return [String] The User-Agent string.
    def user_agent
      base_agent = configuration.user_agent || "ActiveProject Gem (github.com/seuros/activeproject)"
      "#{base_agent} v#{ActiveProject::VERSION}"
    end

    # Returns a memoized instance of the requested adapter.
    # Thread-safe implementation using Concurrent::Map for the adapter registry.
    # @param adapter_type [Symbol] The name of the adapter (e.g., :jira, :trello).
    # @param instance_name [Symbol] The name of the adapter instance (default: :primary).
    # @return [ActiveProject::Adapters::Base] An instance of a specific adapter class that inherits from Base.
    # @raise [ArgumentError] if the adapter configuration is missing or invalid.
    # @raise [LoadError] if the adapter class cannot be found.
    # @raise [NameError] if the adapter class cannot be found after loading the file.
    def adapter(adapter_type, instance_name = :primary)
      key = "#{adapter_type}_#{instance_name}".to_sym

      adapter_registry.fetch_or_store(key) do
        config = configuration.adapter_config(adapter_type, instance_name)

        unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
          available_configs = list_available_configurations

          error_message = "Configuration for adapter ':#{adapter_type}' (instance ':#{instance_name}') not found or invalid.\n\n"

          if available_configs.empty?
            error_message += "No adapters are currently configured. "
          else
            error_message += "Available configurations:\n"
            available_configs.each do |adapter_key, config_type|
              error_message += "  * #{adapter_key} (#{config_type})\n"
            end
          end

          error_message += "\nTo configure, use:\n"
          error_message += "  ActiveProject.configure do |config|\n"
          error_message += "    config.add_adapter :#{adapter_type}, :#{instance_name}, { your_options_here }\n"
          error_message += "  end"

          raise ArgumentError, error_message
        end

        adapter_class_name = "ActiveProject::Adapters::#{adapter_type.to_s.capitalize}Adapter"

        begin
          require "active_project/adapters/#{adapter_type}_adapter"
        rescue LoadError => e
          error_message = "Could not load adapter '#{adapter_type}'.\n"
          error_message += "Make sure you have defined the class #{adapter_class_name} in active_project/adapters/#{adapter_type}_adapter.rb"
          raise LoadError, error_message
        end

        begin
          adapter_class = Object.const_get(adapter_class_name)
        rescue NameError => e
          error_message = "Could not find adapter class #{adapter_class_name}.\n"
          error_message += "Make sure you have defined the class correctly in active_project/adapters/#{adapter_type}_adapter.rb"
          raise NameError, error_message
        end

        adapter_class.new(config: config)
      end
    end

    # Lists all available configurations in the format adapter_name:instance_name
    # @return [Hash] A hash mapping configuration keys to their configuration types
    def list_available_configurations
      result = {}
      configuration.adapter_configs.each do |key, config|
        config_type = config.class.name.split("::").last
        result[key] = config_type
      end
      result
    end

    # Returns a thread-safe map that stores adapter instances
    # @return [Concurrent::Map] Thread-safe hash implementation
    def adapter_registry
      @adapter_registry ||= Concurrent::Map.new
    end
  end
end

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.inflector.inflect("activeproject" => "ActiveProject")
loader.do_not_eager_load("#{__dir__}/active_project/adapters")
loader.ignore("#{__dir__}/active_project/errors.rb")
loader.ignore("#{__dir__}/active_project/version.rb")
loader.ignore("#{__dir__}/active_project/railtie.rb")
loader.setup
