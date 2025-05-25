# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubProject
      #
      # Project-item CRUD operations for GitHub Projects v2.
      #
      # This module exists because GitHub decided that "issues," "drafts," and "project items"
      # are three different species, and we have to *unify the galaxy.*
      #
      module Issues
        include Helpers
        # Like everything on GitHub: decent default, weird edge cases. Why not 25 like a normal person?
        DEFAULT_ITEM_PAGE_SIZE = 50

        #
        # Lists *every* issue or draft in a GitHub Project.
        # Handles pagination the GitHub way: manually, painfully, endlessly.
        #
        # options[:page_size] → control how much data you want per jump into hyperspace.
        #
        def list_issues(project_id, options = {})
          page_size = options.fetch(:page_size, DEFAULT_ITEM_PAGE_SIZE)
          query = <<~GQL
            query($id:ID!, $first:Int!, $after:String){
              node(id:$id){
                ... on ProjectV2{
                  items(first:$first, after:$after){
                    nodes{
                      id type content{__typename ... on Issue{ id number title body state
                        assignees(first:10){nodes{login id}}
                        reporter:author{login} } }
                      createdAt updatedAt
                    }
                    pageInfo{hasNextPage endCursor}
                  }
                }
              }
            }
          GQL

          nodes = fetch_all_pages(
            query,
            variables: { id: project_id, first: page_size },
            connection_path: %w[node items]
          ) { |vars| request_gql(query: query, variables: vars) }

          nodes.map { |n| map_item_to_issue(n, project_id) }
        end

        #
        # Fetch a single issue or draft item by its mysterious GraphQL node ID.
        # If it's missing, you get a 404 so you can take a day off.
        #
        def find_issue(item_id, _ctx = {})
          query = <<~GQL
            query($id:ID!){
              node(id:$id){
                ... on ProjectV2Item{
                  id
                  type
                  fieldValues(first:20){
                    nodes{
                      ... on ProjectV2ItemFieldTextValue{
                        text
                        field { ... on ProjectV2FieldCommon { name } }
                      }
                    }
                  }
                  content{
                    __typename
                    ... on Issue{
                      id number title body state
                      assignees(first:10){nodes{login id}}
                      reporter:author{login}
                    }
                  }
                  createdAt
                  updatedAt
                  project { id }
                }
              }
            }
          GQL
          node = request_gql(query: query, variables: { id: item_id })["node"]
          raise NotFoundError, "Project item #{item_id} not found" unless node

          map_item_to_issue(node, node.dig("project", "id"))
        end

        #
        # Create a new issue in the project.
        #
        # Choose your destiny:
        #   - Pass :content_id → links an existing GitHub Issue or PR into the project.

        def create_issue(project_id, attrs)
          content_id = attrs[:content_id] or
            raise ArgumentError, "DraftIssues not supported—pass :content_id of a real Issue or PR"

          mutation = <<~GQL
            mutation($project:ID!, $content:ID!) {
              addProjectV2ItemById(input:{projectId:$project, contentId:$content}) {
                item { id }
              }
            }
          GQL

          data = request_gql(
            query: mutation,
            variables: { project: project_id, content: content_id }
          ).dig("addProjectV2ItemById", "item")

          find_issue(data["id"])
        end

        #
        # Update fields on an existing ProjectV2Item.
        #
        # You can adjust:
        #   - Title (text field)
        #   - Status (single-select nightmare field)
        #
        # NOTE: Requires you to preload field mappings, because GitHub’s GraphQL API
        # refuses to help unless you memorize all their withcrafts.
        #
        def update_issue_original(project_id, item_id, attrs = {})
          field_ids = project_field_ids(project_id)

          # -- Update Title (basic) --
          if attrs[:title]
            mutation = <<~GQL
              mutation($proj:ID!, $item:ID!, $field:ID!, $title:String!) {
                updateProjectV2ItemFieldValue(input:{
                  projectId:$proj, itemId:$item,
                  fieldId:$field, value:{text:$title}
                }) { projectV2Item { id } }
              }
            GQL
            request_gql(query: mutation,
                        variables: {
                          proj: project_id,
                          item: item_id,
                          field: field_ids.fetch("Title"),
                          title: attrs[:title]
                        })
          end

          # -- Update Status (dark side difficulty) --
          if attrs[:status]
            status_field_id = field_ids.fetch("Status")
            option_id = status_option_id(project_id, attrs[:status])
            mutation = <<~GQL
              mutation($proj:ID!, $item:ID!, $field:ID!, $opt:String!) {
                updateProjectV2ItemFieldValue(input:{
                  projectId:$proj, itemId:$item,
                  fieldId:$field, value:{singleSelectOptionId:$opt}
                }) { projectV2Item { id } }
              }
            GQL
            request_gql(query: mutation,
                        variables: { proj: project_id, item: item_id,
                                     field: status_field_id, opt: option_id })
          end

          find_issue(item_id)
        end

        #
        # Delete a ProjectV2Item from a project.
        # No soft delete, no grace period — just *execute Order 66*.
        #
        def delete_issue_original(project_id, item_id)
          mutation = <<~GQL
            mutation($proj:ID!, $item:ID!){
              deleteProjectV2Item(input:{projectId:$proj, itemId:$item}){deletedItemId}
            }
          GQL
          request_gql(query: mutation,
                      variables: { proj: project_id, item: item_id })
          true
        end

        #
        # Check if a status symbol like :in_progress is known for a project.
        # Avoids exploding like fukushima reactor if you try to set a status that doesn't exist.
        #
        def status_known?(project_id, sym)
          (@status_cache && @status_cache[project_id] || {}).key?(sym)
        end

        private

        #
        # Turn a GraphQL project item node into a clean, beautiful Resources::Issue object.
        #
        # Because the only thing worse than undocumented fields is undocumented *types.*
        #
        def map_item_to_issue(node, project_id)
          content = node["content"] || {}
          typename = content["__typename"]
          title =
            if typename == "Issue"
              content["title"]
            else
              # Draft card – try to pull “Title” field value
              fv = node.dig("fieldValues", "nodes")
                       &.find { |n| n.dig("field", "name") == "Title" }
              "(draft) #{fv&.dig('text')}"
            end
          description = typename == "Issue" ? content["body"] : nil
          status = :open
          status = :closed if typename == "Issue" && content["state"] == "CLOSED"

          assignees = if content["assignees"] && content["assignees"]["nodes"]
                        content["assignees"]["nodes"].map { |u| map_user(u) }
          else
                        []
          end

          reporter = map_user(content["reporter"]) if content["reporter"]

          Resources::Issue.new(
            self,
            id: node["id"],
            key: typename == "Issue" ? content["number"] : nil,
            title: title,
            description: description,
            status: status,
            assignees: assignees,
            reporter: reporter,
            project_id: project_id,
            created_at: Time.parse(node["createdAt"]),
            updated_at: Time.parse(node["updatedAt"]),
            due_on: nil,
            priority: nil,
            adapter_source: :github,
            raw_data: node
          )
        end

        #
        # Look up the option ID for a given status symbol, or raise a tantrum.
        #
        def status_option_id(project_id, symbol)
          @status_cache ||= Concurrent::Map.new
          cache = (@status_cache[project_id] ||= load_status_options(project_id))

          return cache[symbol] if cache.key?(symbol)

          available = cache.keys.map(&:inspect).join(", ")
          raise ArgumentError,
                "No status #{symbol.inspect} in project; valid symbols are: #{available}"
        end

        #
        # Load all valid status options for a project’s "Status" field.
        # Only way to win is not to play.
        #
        def load_status_options(project_id)
          q = <<~GQL
            query($id:ID!){
              node(id:$id){
                ... on ProjectV2{
                  field(name:"Status"){
                    ... on ProjectV2SingleSelectField{
                      options{ id name }
                    }
                  }
                }
              }
            }
          GQL

          opts = request_gql(query: q, variables: { id: project_id })
                 .dig("node", "field", "options")

          opts.to_h do |o|
            key = o["name"].downcase.tr(" ", "_").to_sym
            [ key, o["id"] ]
          end
        end
      end
    end
  end
end
