# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubProject
      module Projects
        include Helpers

        #
        # List all ProjectsV2 for a GitHub user.
        #
        # Because nothing says "weekend hustle" like spinning up yet another project,
        # posting "🚀 Day 1 of #BuildInPublic" on X, and immediately abandoning it by Tuesday.
        #
        def list_projects(options = {})
          owner     = options[:owner] || @config.owner
          page_size = options.fetch(:page_size, 50)

          # ---- build query template ------------------------------------------------
          query_tmpl = lambda { |kind|
            # rubocop:disable Layout/LineLength
            <<~GQL
              query($login:String!, $first:Int!, $after:String){
                #{kind}(login:$login){
                  projectsV2(first:$first, after:$after){
                    nodes{ id number title }
                    pageInfo{ hasNextPage endCursor }
                  }
                }
              }
            GQL
            # rubocop:enable Layout/LineLength
          }

          # ---- fetch pages, trying user first, then organisation -------------------
          begin
            nodes = fetch_all_pages(
              query_tmpl.call("user"),
              variables: { login: owner, first: page_size },
              connection_path: %w[user projectsV2]
            )
          rescue ActiveProject::NotFoundError, ActiveProject::ValidationError
            nodes = fetch_all_pages(
              query_tmpl.call("organization"),
              variables: { login: owner, first: page_size },
              connection_path: %w[organization projectsV2]
            )
          end

          nodes.map { |proj| build_project_resource(proj) }
        end

        #
        # Find a project either by its public-facing number or internal node ID.
        #
        # Supports both:
        #  - people who proudly know their project number (respect)
        #  - and people copy-pasting weird node IDs at 2am on a Saturday.
        #
        def find_project(id_or_number)
          if id_or_number.to_s =~ /^\d+$/
            # UI-visible number path: the civilized way.
            owner = @config.owner
            num = id_or_number.to_i
            q = <<~GQL
              query($login: String!, $num: Int!) {
                user(login: $login) {
                  projectV2(number: $num) { id number title }
                }
              }
            GQL
            data = request_gql(query: q, variables: { login: owner, num: num })
            proj = data.dig("user", "projectV2") or raise NotFoundError
          else
            # Node ID path: the "I swear I know what I'm doing" path.
            proj = request_gql(
              query: "query($id:ID!){ node(id:$id){ ... on ProjectV2 { id number title }}}",
              variables: { id: id_or_number }
            )["node"]
          end
          build_project_resource(proj)
        end

        #
        # Create a shiny new GitHub Project.
        #
        # Required:
        #  - :name → preferably a trendy one like "TasklyAgent" or "ZenboardAI"
        #
        # Step 1: create project.
        # Step 2: tweet "Just shipped something huge 🔥 #buildinpublic".
        # Step 3: forget about it.
        #
        def create_project(attributes)
          name = attributes[:name] or raise ArgumentError, "Missing :name"
          owner_id = owner_node_id(@config.owner)
          q = <<~GQL
            mutation($name:String!, $owner:ID!){
              createProjectV2(input:{title:$name,ownerId:$owner}) { projectV2 { id number title } }
            }
          GQL
          proj = request_gql(query: q, variables: { name: name, owner: owner_id })
                 .dig("createProjectV2", "projectV2")
          build_project_resource(proj)
        end

        #
        # Soft-delete a project by "closing" it.
        #
        # GitHub doesn't believe in real deletion yet, only ghosting.
        # Just like that app idea you posted about but never launched.
        #
        def delete_project(project_id)
          q = <<~GQL
            mutation($id:ID!){ updateProjectV2(input:{projectId:$id, closed:true}) { clientMutationId } }
          GQL
          request_gql(query: q, variables: { id: project_id })
          true
        end

        private

        #
        # Turn raw GraphQL sludge into a proper Project resource.
        #
        # For when you need your side project to at least *look* real in screenshots.
        #
        def build_project_resource(proj)
          Resources::Project.new(self,
                                 id: proj["id"],
                                 key: proj["number"],
                                 name: proj["title"],
                                 adapter_source: :github,
                                 raw_data: proj)
        end
      end
    end
  end
end
