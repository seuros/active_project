require "zeitwerk"
require_relative "active_project/errors"
require_relative "active_project/version"

module ActiveProject
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end


    # Returns the configured User-Agent string, including the gem version.
    # @return [String] The User-Agent string.
    def user_agent
      base_agent = configuration.user_agent || "ActiveProject Gem (github.com/seuros/activeproject)"
      "#{base_agent} v#{ActiveProject::VERSION}"
    end

    # Returns a memoized instance of the requested adapter.
    # @param adapter_name [Symbol] The name of the adapter (e.g., :jira, :trello).
    # @return [Adapters::Base] An instance of the requested adapter.
    # @raise [ArgumentError] if the adapter configuration is missing or invalid.
    # @raise [LoadError] if the adapter class cannot be found.
    def adapter(adapter_name)
      @adapters ||= {}
      @adapters[adapter_name] ||= begin
        config = configuration.adapter_config(adapter_name)

        unless config.is_a?(ActiveProject::Configurations::BaseAdapterConfiguration)
          raise ArgumentError, "Configuration for adapter ':#{adapter_name}' not found or invalid. Use ActiveProject.configure."
        end

        # Use string-based constant lookup with the full namespace path
        adapter_class_name = "ActiveProject::Adapters::#{adapter_name.to_s.capitalize}Adapter"

        # Ensure the adapter class is loaded
        require "active_project/adapters/#{adapter_name}_adapter"

        # Get the constant with the full path
        adapter_class = Object.const_get(adapter_class_name)

        adapter_class.new(config: config)
      rescue LoadError, NameError => e
        raise LoadError, "Could not find adapter class #{adapter_class_name}: #{e.message}"
      end
    end
  end
end

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.inflector.inflect("activeproject" => "ActiveProject")
loader.do_not_eager_load("#{__dir__}/active_project/adapters")
loader.ignore("#{__dir__}/active_project/errors.rb")
loader.ignore("#{__dir__}/active_project/version.rb")
loader.setup
