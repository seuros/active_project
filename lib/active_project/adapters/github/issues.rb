# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Github
      module Issues
        # Lists GitHub issues within a specific repository (project).
        # @param project_id [String] The repository name or full_name
        # @param options [Hash] Optional filtering options.
        #   Supported keys:
        #   - status: 'open', 'closed', or 'all' (default: 'open')
        #   - page: Page number for pagination (default: 1)
        #   - per_page: Issues per page (default: 30, max: 100)
        #   - sort: 'created', 'updated', or 'comments' (default: 'created')
        #   - direction: 'asc' or 'desc' (default: 'desc')
        # @return [Array<ActiveProject::Resources::Issue>]
        def list_issues(project_id, options = {})
          # Determine the repository path to use
          repo_path = determine_repo_path(project_id)
          
          # Build query parameters
          query = {}
          query[:state] = options[:status] || 'open'
          query[:page] = options[:page] if options[:page]
          query[:per_page] = options[:per_page] if options[:per_page]
          query[:sort] = options[:sort] if options[:sort]
          query[:direction] = options[:direction] if options[:direction]
          
          issues_data = make_request(:get, "#{repo_path}/issues", nil, query)
          return [] unless issues_data.is_a?(Array)
          
          issues_data.map { |issue_data| map_issue_data(issue_data) }
        end
        
        # Finds a specific issue by its number.
        # @param id [String, Integer] The issue number within the repository.
        # @param context [Hash] Optional context.
        #   Supported keys:
        #   - repo_owner: Repository owner if different from configured owner
        #   - repo_name: Repository name if different from configured repo
        # @return [ActiveProject::Resources::Issue]
        def find_issue(id, context = {})
          # Determine the repository path to use
          repo_path = if context[:repo_owner] && context[:repo_name]
                       "repos/#{context[:repo_owner]}/#{context[:repo_name]}"
                     else
                       @repo_path
                     end
          
          issue_data = make_request(:get, "#{repo_path}/issues/#{id}")
          map_issue_data(issue_data)
        end
        
        # Creates a new issue in a GitHub repository.
        # @param project_id [String] The repository name or full_name
        # @param attributes [Hash] Issue attributes.
        #   Required: :title
        #   Optional: :description (body), :assignees (array of usernames)
        # @return [ActiveProject::Resources::Issue]
        def create_issue(project_id, attributes)
          # Determine the repository path to use
          repo_path = determine_repo_path(project_id)
          
          unless attributes[:title] && !attributes[:title].empty?
            raise ArgumentError, "Missing required attribute for GitHub issue creation: :title"
          end
          
          data = {
            title: attributes[:title],
            body: attributes[:description]
          }
          
          # Convert assignees if present
          if attributes[:assignees] && attributes[:assignees].is_a?(Array)
            if attributes[:assignees].all? { |a| a.is_a?(Hash) && a[:name] }
              data[:assignees] = attributes[:assignees].map { |a| a[:name] }
            else
              data[:assignees] = attributes[:assignees]
            end
          end
          
          # Add labels if present
          data[:labels] = attributes[:labels] if attributes[:labels]
          
          issue_data = make_request(:post, "#{repo_path}/issues", data)
          map_issue_data(issue_data)
        end
        
        # Updates an existing issue in GitHub.
        # @param id [String, Integer] The issue number.
        # @param attributes [Hash] Issue attributes to update.
        #   Supported keys: :title, :description (body), :status (state), :assignees
        # @param context [Hash] Optional context.
        #   Supported keys:
        #   - repo_owner: Repository owner if different from configured owner
        #   - repo_name: Repository name if different from configured repo
        # @return [ActiveProject::Resources::Issue]
        def update_issue(id, attributes, context = {})
          # Determine the repository path to use
          repo_path = if context[:repo_owner] && context[:repo_name]
                       "repos/#{context[:repo_owner]}/#{context[:repo_name]}"
                     else
                       @repo_path
                     end
          
          data = {}
          data[:title] = attributes[:title] if attributes.key?(:title)
          data[:body] = attributes[:description] if attributes.key?(:description)
          
          # Handle status mapping
          if attributes.key?(:status)
            state = case attributes[:status]
                   when :open, :in_progress then "open"
                   when :closed then "closed"
                   else attributes[:status].to_s
                   end
            data[:state] = state
          end
          
          # Convert assignees if present
          if attributes.key?(:assignees)
            if attributes[:assignees].nil? || attributes[:assignees].empty?
              data[:assignees] = []
            elsif attributes[:assignees].all? { |a| a.is_a?(Hash) && a[:name] }
              data[:assignees] = attributes[:assignees].map { |a| a[:name] }
            else
              data[:assignees] = attributes[:assignees]
            end
          end
          
          issue_data = make_request(:patch, "#{repo_path}/issues/#{id}", data)
          map_issue_data(issue_data)
        end
        
        # Attempts to delete an issue in GitHub, but since GitHub doesn't support
        # true deletion, it closes the issue instead.
        # @param id [String, Integer] The issue number.
        # @param context [Hash] Optional context.
        # @return [Boolean] Always returns false since GitHub doesn't support true deletion.
        def delete_issue(id, context = {})
          # GitHub doesn't support true deletion of issues
          # The best we can do is close the issue
          update_issue(id, { status: :closed }, context)
          false # Return false indicating true deletion is not supported
        end
        
        private
        
        # Determines the repository path to use based on project_id.
        # @param project_id [String] Repository name or full_name
        # @return [String] The repository API path
        def determine_repo_path(project_id)
          # If project_id matches configured repo or is the same as the full_name, use @repo_path
          if project_id.to_s == @config.options[:repo] || 
             project_id.to_s == "#{@config.options[:owner]}/#{@config.options[:repo]}"
            return @repo_path
          end
          
          # If project_id contains a slash, assume it's a full_name
          if project_id.to_s.include?("/")
            return "repos/#{project_id}"
          end
          
          # Otherwise, assume it's just a repo name and use the configured owner
          "repos/#{@config.options[:owner]}/#{project_id}"
        end
        
        # Maps raw GitHub issue data to an ActiveProject::Resources::Issue
        # @param issue_data [Hash] Raw issue data from GitHub API
        # @return [ActiveProject::Resources::Issue]
        def map_issue_data(issue_data)
          # Map state to status
          status = @config.status_mappings[issue_data["state"]] || :unknown
          
          # Map assignees
          assignees = []
          if issue_data["assignees"] && !issue_data["assignees"].empty?
            assignees = issue_data["assignees"].map do |assignee|
              Resources::User.new(
                self,
                id: assignee["id"].to_s,
                name: assignee["login"],
                adapter_source: :github,
                raw_data: assignee
              )
            end
          end
          
          # Map reporter (user who created the issue)
          reporter = nil
          if issue_data["user"]
            reporter = Resources::User.new(
              self,
              id: issue_data["user"]["id"].to_s,
              name: issue_data["user"]["login"],
              adapter_source: :github,
              raw_data: issue_data["user"]
            )
          end
          
          # Extract project ID (repo name) from the URL
          project_id = nil
          if issue_data["repository_url"]
            # Extract owner/repo from repository_url
            repo_parts = issue_data["repository_url"].split("/")
            project_id = repo_parts.last(2).join("/")
          elsif issue_data["url"]
            # Try to extract from issue URL
            url_parts = issue_data["url"].split("/")
            if url_parts.include?("repos")
              repos_index = url_parts.index("repos")
              if repos_index && repos_index + 2 < url_parts.length
                project_id = "#{url_parts[repos_index + 1]}/#{url_parts[repos_index + 2]}"
              end
            end
          end
          
          # If still not found, use configured repo
          project_id ||= "#{@config.options[:owner]}/#{@config.options[:repo]}"
          
          Resources::Issue.new(
            self,
            id: issue_data["id"].to_s,
            key: issue_data["number"].to_s,
            title: issue_data["title"],
            description: issue_data["body"],
            status: status,
            assignees: assignees,
            reporter: reporter,
            project_id: project_id,
            created_at: issue_data["created_at"] ? Time.parse(issue_data["created_at"]) : nil,
            updated_at: issue_data["updated_at"] ? Time.parse(issue_data["updated_at"]) : nil,
            due_on: nil, # GitHub issues don't have a built-in due date
            priority: nil, # GitHub issues don't have a built-in priority
            adapter_source: :github,
            raw_data: issue_data
          )
        end
      end
    end
  end
end