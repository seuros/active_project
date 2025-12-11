# frozen_string_literal: true

module ActiveProject
  # Represents an association between resources (e.g., project.issues).
  # Delegates finding/creating methods to the adapter, providing owner context.
  class AssociationProxy
    # @param owner [Resources::BaseResource] The resource instance owning the association.
    # @param adapter [Adapters::Base] The adapter instance.
    # @param association_name [Symbol] The name of the association (e.g., :issues, :comments).
    def initialize(owner:, adapter:, association_name:)
      @owner = owner
      @adapter = adapter
      @association_name = association_name
      # Determine target resource class based on association name (simple heuristic for now)
      @target_resource_class = case association_name
      when :issues then Resources::Issue
      when :comments then Resources::Comment
      # Add other associations like :project for an issue?
      else raise "Unknown association: #{association_name}"
      end
    end

    # --- Proxy Methods ---

    # Fetches all associated resources.
    # Example: project.issues.all -> adapter.list_issues(project.id)
    # @param options [Hash] Additional options for the list method.
    # @return [Array<BaseResource>]
    def all(options = {})
      list_method = determine_list_method
      # Pass owner's ID as the primary context, then options
      # Ensure owner.id is accessed correctly
      owner_id = @owner.respond_to?(:id) ? @owner.id : nil
      raise "Owner object #{@owner.inspect} does not have an ID for association call." unless owner_id

      @adapter.send(list_method, owner_id, options)
    end

    # Finds a specific associated resource by ID.
    # Example: project.issues.find(issue_id) -> adapter.find_issue(issue_id, { project_id: project.id })
    # @param id [String, Integer] The ID of the resource to find.
    # @return [BaseResource, nil]
    def find(id)
      find_method = determine_find_method
      # Pass owner context needed by the find method
      context = determine_context
      @adapter.send(find_method, id, context)
    rescue ActiveProject::NotFoundError
      nil
    end

    # Filters associated resources based on conditions.
    # Example: project.issues.where(status: :open)
    # Currently performs client-side filtering on #all results.
    # @param conditions [Hash] Conditions to filter by.
    # @return [Array<BaseResource>]
    def where(conditions)
      # Basic client-side filtering for now
      # Note: This calls the proxy's #all method, which passes owner context
      all.select do |resource|
        conditions.all? do |key, value|
          resource.respond_to?(key) && resource.send(key) == value
        end
      end
    end

    # Builds a new, unsaved associated resource instance.
    # Example: project.issues.build(title: 'New')
    # @param attributes [Hash] Attributes for the new resource.
    # @return [BaseResource]
    def build(attributes = {})
      # Automatically add owner context (e.g., project_id)
      owner_key = :"#{@owner.class.name.split('::').last.downcase}_id"
      merged_attrs = attributes.merge(
        owner_key => @owner.id,
        adapter_source: @adapter.class.name.split("::").last.sub("Adapter", "").downcase.to_sym,
        raw_data: attributes
      )
      # Ensure target resource class is correctly determined and used
      @target_resource_class.new(@adapter, merged_attrs)
    end

    alias new build

    # Creates and saves a new associated resource.
    # Example: project.issues.create(title: 'New', list_id: '...')
    # @param attributes [Hash] Attributes for the new resource.
    # @return [BaseResource]
    # @raise [NotImplementedError] Currently raises because #save is not fully implemented on resource.
    def create(attributes = {})
      create_method = determine_create_method
      determine_context # Get owner context
      # Pass owner ID/context first, then attributes
      owner_id = @owner.respond_to?(:id) ? @owner.id : nil
      raise "Owner object #{@owner.inspect} does not have an ID for association call." unless owner_id

      @adapter.send(create_method, owner_id, attributes)
      # NOTE: This currently returns the result from the adapter directly.
      # A full implementation would likely build and then save, or re-fetch.
    end

    private

    # Determines the context hash needed for adapter calls based on the owner.
    def determine_context
      # Basecamp and GitHub Project need project_id for issue/comment operations
      if (@adapter.is_a?(Adapters::BasecampAdapter) || @adapter.is_a?(Adapters::GithubProjectAdapter)) &&
         (@association_name == :issues || @association_name == :comments)
        { project_id: @owner.id }
      else
        {} # Other adapters might not need explicit context hash for find_issue/find_comment
      end
    end

    # Determines the correct adapter list method based on association name.
    def determine_list_method
      method_name = :"list_#{@association_name}"
      unless @adapter.respond_to?(method_name)
        raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}"
      end

      method_name
    end

    # Determines the correct adapter find method based on association name.
    def determine_find_method
      # Assume find method name matches singular association name (issue, comment)
      # Need ActiveSupport::Inflector for singularize, or implement basic logic
      singular_name = @association_name == :issues ? :issue : @association_name.to_s.chomp("s").to_sym
      method_name = :"find_#{singular_name}"
      unless @adapter.respond_to?(method_name)
        raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}"
      end

      method_name
    end

    # Determines the correct adapter create method based on association name.
    def determine_create_method
      # Assume create method name matches singular association name (issue, comment)
      singular_name = @association_name == :issues ? :issue : @association_name.to_s.chomp("s").to_sym
      method_name = :"create_#{singular_name}"
      unless @adapter.respond_to?(method_name)
        raise NotImplementedError, "#{@adapter.class.name} does not implement ##{method_name}"
      end

      method_name
    end
  end
end
