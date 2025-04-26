# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubProject
      module Comments
        #
        # Add a comment to the underlying Issue or PR of a ProjectV2Item.
        # For draft items (no linked content) this raises NotImplementedError,
        # because GitHub does not expose a comment thread for drafts.
        #
        # @param item_id [String] ProjectV2Item node-ID
        # @param body    [String] Markdown text
        # @param ctx     [Hash]   MUST include :content_node_id for speed,
        #                         otherwise we’ll query.
        #
        def add_comment(item_id, body, ctx = {})
          content_id =
            ctx[:content_node_id] ||
            begin
              q = <<~GQL
                query($id:ID!){
                  node(id:$id){
                    ... on ProjectV2Item{ content{ __typename ... on Issue{id} ... on PullRequest{id} } }
                  }
                }
              GQL
              request_gql(query: q, variables: { id: item_id })
                .dig("node", "content", "id")
            end

          raise NotImplementedError, "Draft cards cannot receive comments" unless content_id

          mutation = <<~GQL
            mutation($subject:ID!, $body:String!){
              addComment(input:{subjectId:$subject, body:$body}){ commentEdge{ node{ id body author{login}
                createdAt updatedAt } } }
            }
          GQL
          comment_node = request_gql(query: mutation,
                                     variables: { subject: content_id, body: body })
                         .dig("addComment", "commentEdge", "node")

          map_comment(comment_node, item_id)
        end
        alias create_comment add_comment

        def update_comment(comment_id, body)
          mutation = <<~GQL
            mutation($id:ID!, $body:String!){
              updateIssueComment(input:{id:$id, body:$body}){
                issueComment { id body updatedAt }
              }
            }
          GQL
          node = request_gql(query: mutation,
                             variables: { id: comment_id, body: body })
                 .dig("updateIssueComment", "issueComment")

          map_comment(node, node["id"])
        end

        def delete_comment(comment_id)
          mutation = <<~GQL
            mutation($id:ID!){
              deleteIssueComment(input:{id:$id}){ clientMutationId }
            }
          GQL
          request_gql(query: mutation, variables: { id: comment_id })
          true
        end

        private

        def map_comment(node, item_id)
          Resources::Comment.new(
            self,
            id: node["id"],
            body: node["body"],
            author: map_user(node["author"]),
            created_at: Time.parse(node["createdAt"]),
            updated_at: Time.parse(node["updatedAt"]),
            issue_id: item_id,
            adapter_source: :github,
            raw_data: node
          )
        end
      end
    end
  end
end
