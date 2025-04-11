# frozen_string_literal: true

module ActiveProject
  module Adapters
    module Github
      module Projects
        # Lists projects accessible by the configured credentials.
        # In GitHub's context, this returns the configured repository as a "project".
        # @return [Array<ActiveProject::Resources::Project>] Array containing the repository as a project
        def list_projects
          # Get the configured repository
          repo_data = make_request(:get, @repo_path)
          [map_repository_to_project(repo_data)]
        end

        # Finds a specific project by its ID or name.
        # In GitHub's context, this finds a repository.
        # @param id [String, Integer] The ID or full_name of the repository
        # @return [ActiveProject::Resources::Project, nil] The repository as a project
        def find_project(id)
          # If id is nil or empty, use the configured repo
          if id.nil? || id.to_s.empty?
            id = @config.options[:repo]
          end
          
          # If id matches our configured repo, return that
          if id.to_s == @config.options[:repo] || id.to_s == "#{@config.options[:owner]}/#{@config.options[:repo]}"
            repo_data = make_request(:get, @repo_path)
            return map_repository_to_project(repo_data)
          end
          
          # Otherwise, try to find by ID or full name
          begin
            repo_data = make_request(:get, "repositories/#{id}")
            map_repository_to_project(repo_data)
          rescue NotFoundError
            # Try with full name path format (owner/repo)
            if id.to_s.include?("/")
              repo_data = make_request(:get, "repos/#{id}")
              map_repository_to_project(repo_data)
            else
              # Try with owner + repo name
              begin
                repo_data = make_request(:get, "repos/#{@config.options[:owner]}/#{id}")
                map_repository_to_project(repo_data)
              rescue NotFoundError
                raise NotFoundError, "GitHub repository with ID or name '#{id}' not found"
              end
            end
          end
        end

        # Creates a new repository (project).
        # Note: In most cases users will already have repositories set up.
        # @param attributes [Hash] Repository attributes (name, description, etc.)
        # @return [ActiveProject::Resources::Project] The created repository as a project
        def create_project(attributes)
          # Create in organization or user account based on config
          owner = @config.options[:owner]
          
          # Determine if creating in org or personal account
          begin
            make_request(:get, "orgs/#{owner}")
            path = "orgs/#{owner}/repos"
          rescue NotFoundError
            path = "user/repos"
          end
          
          data = {
            name: attributes[:name],
            description: attributes[:description],
            private: attributes[:private] || false,
            has_issues: attributes[:has_issues] || true
          }
          
          repo_data = make_request(:post, path, data)
          map_repository_to_project(repo_data)
        end

        # Deletes a repository.
        # Note: This is a destructive operation and generally not recommended.
        # @param repo_id [String] The ID or full_name of the repository
        # @return [Boolean] True if successfully deleted
        def delete_project(repo_id)
          # Find the repository first to get its full path
          repo = find_project(repo_id)
          raise NotFoundError, "Repository not found" unless repo
          
          # Delete requires the full path in "owner/repo" format
          full_path = repo.name # We store full_name in the name field
          make_request(:delete, "repos/#{full_path}")
          true
        rescue NotFoundError
          false
        end

        private

        # Maps a GitHub repository to an ActiveProject project resource.
        # @param repo_data [Hash] Raw repository data from GitHub API
        # @return [ActiveProject::Resources::Project] The mapped project resource
        def map_repository_to_project(repo_data)
          Resources::Project.new(
            self,
            id: repo_data["id"].to_s,
            key: repo_data["name"],               # Repository name (without owner)
            name: repo_data["full_name"],         # Full repository name (owner/repo)
            description: repo_data["description"],
            adapter_source: :github,
            raw_data: repo_data
          )
        end
      end
    end
  end
end