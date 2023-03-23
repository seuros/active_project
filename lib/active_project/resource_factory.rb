# frozen_string_literal: true

module ActiveProject
  # Factory class for creating and finding resource objects (Project, Issue, etc.)
  # associated with a specific adapter.
  class ResourceFactory
    # @param adapter [Adapters::Base] The adapter instance.
    # @param resource_class [Class] The resource class (e.g., Resources::Project).
    def initialize(adapter:, resource_class:)
      @adapter = adapter
      @resource_class = resource_class
    end

    # Fetches all resources of the associated type.
    # Delegates to the appropriate adapter list method.
    # @param args [Array] Arguments to pass to the adapter's list method (e.g., project_id for issues).
    # @return [Array<BaseResource>] An array of resource objects.
    def all(*args)
      list_method = determine_list_method
      options = args.last.is_a?(Hash) ? args.pop : {}
      primary_arg = args.first

      # Call adapter method with appropriate arguments
      if primary_arg
        @adapter.send(list_method, primary_arg, options)
      else
        # Handle case where list method might not take options (like list_projects)
        if @adapter.method(list_method).arity == 0
           @adapter.send(list_method)
        else
           @adapter.send(list_method, options)
        end
      end
    end

    # Finds a specific resource by its ID.
    # Delegates to the appropriate adapter find method.
    # @param id [String, Integer] The ID or key of the resource.
    # @param context [Hash] Optional context needed by some find methods (e.g., :project_id for Basecamp issues).
    # @return [BaseResource, nil] The found resource object or nil.
    def find(id, context = {})
      find_method = determine_find_method

      # Pass context only if provided and the find method accepts it
      if !context.empty?
        @adapter.send(find_method, id, context)
      else
        @adapter.send(find_method, id)
      end
    rescue ActiveProject::NotFoundError
      nil # Return nil if the resource is not found by the adapter
    end

    # Fetches the first resource of the associated type.
    # @param args [Array] Arguments to pass to the adapter's list method.
    # @return [BaseResource, nil] The first resource object found or nil.
    def first(*args)
      all(*args).first
    end

    # Filters resources based on given conditions (client-side).
    # @param conditions [Hash] Conditions to filter by.
    # @param list_args [Array] Arguments for the underlying #all call.
    # @return [Array<BaseResource>] Matching resources.
    def where(conditions, *list_args)
      resources = all(*list_args)
      resources.select do |resource|
        conditions.all? do |key, value|
          resource.respond_to?(key) && resource.send(key) == value
        end
      end
    end

    # Builds a new, unsaved resource instance.
    # @param attributes [Hash] Attributes for the new resource.
    # @return [BaseResource] A new instance of the resource class.
    def build(attributes = {})
      merged_attrs = attributes.merge(
        adapter_source: @adapter.class.name.split("::").last.sub("Adapter", "").downcase.to_sym,
        raw_data: attributes
      )
      @resource_class.new(@adapter, merged_attrs)
    end

    # Builds and saves a new resource instance.
    # @param attributes [Hash] Attributes for the new resource.
    # @return [BaseResource] The created resource object.
    # @raise [NotImplementedError] Currently raises because #save is not implemented.
    def create(attributes = {})
      # Determine the correct adapter create method based on resource type
      create_method = determine_create_method
      # Note: Assumes create methods on adapters take attributes hash directly
      # Context like project_id needs to be part of the attributes hash if required by adapter
      @adapter.send(create_method, attributes)
      # A full implementation would likely involve build then save:
      # resource = build(attributes)
      # resource.save
      # resource
    end

    private

    def determine_list_method
      method_name = case @resource_class.name
      when "ActiveProject::Resources::Project" then :list_projects
      when "ActiveProject::Resources::Issue" then :list_issues
      else raise "Cannot determine list method for #{@resource_class.name}"
      end
      raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}" unless @adapter.respond_to?(method_name)
      method_name
    end

    def determine_find_method
      method_name = case @resource_class.name
      when "ActiveProject::Resources::Project" then :find_project
      when "ActiveProject::Resources::Issue" then :find_issue
      else raise "Cannot determine find method for #{@resource_class.name}"
      end
      raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}" unless @adapter.respond_to?(method_name)
      method_name
    end

    def determine_create_method
      singular_name = @resource_class.name.split("::").last.downcase.to_sym
      method_name = :"create_#{singular_name}"
      raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}" unless @adapter.respond_to?(method_name)
      method_name
    end
  end
end
