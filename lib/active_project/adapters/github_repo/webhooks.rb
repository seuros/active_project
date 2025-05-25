# frozen_string_literal: true

module ActiveProject
  module Adapters
    module GithubRepo
      module Webhooks
        # Validates incoming webhook signature using X-Hub-Signature-256 header
        # @param request_body [String] The raw request body
        # @param signature_header [String] The value of the X-Hub-Signature-256 header
        # @return [Boolean] True if signature is valid or verification is not needed
        def verify_webhook_signature(request_body, signature_header)
          webhook_secret = @config.options[:webhook_secret]

          # No webhook secret configured = no verification needed
          return true if webhook_secret.nil? || webhook_secret.empty?

          # Signature header is required when a secret is configured
          return false unless signature_header

          # GitHub uses 'sha256=' prefix for their signatures
          algorithm, signature = signature_header.split("=", 2)
          return false unless algorithm == "sha256" && signature

          # Calculate expected signature
          expected_signature = OpenSSL::HMAC.hexdigest(
            OpenSSL::Digest.new("sha256"),
            webhook_secret,
            request_body
          )

          # Perform a secure comparison
          secure_compare(signature, expected_signature)
        end

        # Constant-time comparison to prevent timing attacks
        # @param a [String] First string to compare
        # @param b [String] Second string to compare
        # @return [Boolean] True if strings are equal
        def secure_compare(a, b)
          return false if a.bytesize != b.bytesize
          l = a.unpack("C*")

          res = 0
          b.each_byte { |byte| res |= byte ^ l.shift }
          res == 0
        end

        # Parses an incoming webhook payload into a standardized WebhookEvent struct
        # @param request_body [String] The raw request body
        # @param headers [Hash] Hash of request headers
        # @return [ActiveProject::WebhookEvent, nil] The parsed event or nil if not relevant
        def parse_webhook(request_body, headers = {})
          data = JSON.parse(request_body)
          event_type = headers["X-GitHub-Event"]

          case event_type
          when "issues"
            parse_issue_event(data)
          when "issue_comment"
            parse_comment_event(data)
          when "pull_request"
            parse_pull_request_event(data)
          else
            nil # Unsupported event type
          end
        rescue JSON::ParserError
          nil # Return nil for invalid JSON
        end

        private

        # Parses an issue event into a WebhookEvent
        # @param data [Hash] Parsed webhook payload
        # @return [WebhookEvent, nil] The standardized event
        def parse_issue_event(data)
          return nil unless data["issue"]

          action = data["action"]
          issue_data = data["issue"]
          repository = data["repository"]

          # Map GitHub action to our event type
          event_type = case action
          when "opened" then :issue_created
          when "edited" then :issue_updated
          when "closed" then :issue_closed
          when "reopened" then :issue_reopened
          when "assigned", "unassigned" then :issue_assigned
          when "labeled", "unlabeled" then :issue_labeled
          else :issue_updated # Default for other actions
          end

          # Map the issue data
          issue = map_webhook_issue(issue_data)

          # Get project (repository) info
          project_id = repository ? repository["full_name"] : nil

          WebhookEvent.new(
            source: webhook_type,
            type: event_type,
            resource_type: :issue,
            resource_id: issue_data["number"].to_s,
            project_id: project_id,
            data: {
              issue: issue,
              action: action
            }
          )
        end

        # Parses a comment event into a WebhookEvent
        # @param data [Hash] Parsed webhook payload
        # @return [WebhookEvent, nil] The standardized event
        def parse_comment_event(data)
          return nil unless data["comment"] && data["issue"]

          action = data["action"]
          comment_data = data["comment"]
          issue_data = data["issue"]
          repository = data["repository"]

          # Only handle supported actions
          return nil unless [ "created", "edited", "deleted" ].include?(action)

          # Map GitHub action to our event type
          event_type = case action
          when "created" then :comment_created
          when "edited" then :comment_updated
          when "deleted" then :comment_deleted
          else nil
          end

          return nil unless event_type

          # Get project (repository) info
          project_id = repository ? repository["full_name"] : nil

          # Create a webhook event with comment and issue data
          WebhookEvent.new(
            source: webhook_type,
            type: event_type,
            resource_type: :comment,
            resource_id: comment_data["id"].to_s,
            project_id: project_id,
            data: {
              # Map the comment data to a Comment resource
              comment: map_webhook_comment(comment_data, issue_data["number"].to_s),
              # Map the issue data to an Issue resource
              issue: map_webhook_issue(issue_data),
              action: action
            }
          )
        end

        # Parses a pull request event into a WebhookEvent
        # GitHub PRs are mapped to issues for compatibility
        # @param data [Hash] Parsed webhook payload
        # @return [WebhookEvent, nil] The standardized event
        def parse_pull_request_event(data)
          return nil unless data["pull_request"]

          action = data["action"]
          pull_request_data = data["pull_request"]
          repository = data["repository"]

          # Map GitHub action to our event type (treating PRs as a type of issue)
          event_type = case action
          when "opened" then :issue_created
          when "edited" then :issue_updated
          when "closed"
                         pull_request_data["merged"] ? :issue_merged : :issue_closed
          when "reopened" then :issue_reopened
          else :issue_updated # Default for other actions
          end

          # Get project (repository) info
          project_id = repository ? repository["full_name"] : nil

          # Create a synthetic issue from the PR
          # We map PRs to issues for the ActiveProject model
          pr_issue = map_webhook_pull_request_to_issue(pull_request_data)

          WebhookEvent.new(
            source: webhook_type,
            type: event_type,
            resource_type: :issue, # Map PRs to issues for consistency
            resource_id: pull_request_data["number"].to_s,
            project_id: project_id,
            data: {
              issue: pr_issue,
              action: action,
              is_pull_request: true
            }
          )
        end

        # Map webhook issue data to an Issue resource
        # @param issue_data [Hash] Issue data from GitHub webhook
        # @return [ActiveProject::Resources::Issue] Mapped issue resource
        def map_webhook_issue(issue_data)
          return nil unless issue_data

          # Map state to status
          state = issue_data["state"]
          status = @config.status_mappings[state] || (state == "open" ? :open : :closed)

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

          # Map reporter (creator)
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

          # Determine project ID (repository name)
          project_id = issue_data["repository_url"]
          if project_id
            parts = project_id.split("/")
            project_id = "#{parts[-2]}/#{parts[-1]}" if parts.size >= 2
          else
            project_id = "#{@config.options[:owner]}/#{@config.options[:repo]}"
          end

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
            due_on: nil, # GitHub issues don't have due dates
            priority: nil, # GitHub issues don't have priorities
            adapter_source: :github,
            raw_data: issue_data
          )
        end

        # Map webhook comment data to a Comment resource
        # @param comment_data [Hash] Comment data from GitHub webhook
        # @param issue_id [String] The issue ID/number this comment belongs to
        # @return [ActiveProject::Resources::Comment] Mapped comment resource
        def map_webhook_comment(comment_data, issue_id)
          return nil unless comment_data

          # Map author
          author = nil
          if comment_data["user"]
            author = Resources::User.new(
              self,
              id: comment_data["user"]["id"].to_s,
              name: comment_data["user"]["login"],
              adapter_source: :github,
              raw_data: comment_data["user"]
            )
          end

          Resources::Comment.new(
            self,
            id: comment_data["id"].to_s,
            body: comment_data["body"],
            author: author,
            created_at: comment_data["created_at"] ? Time.parse(comment_data["created_at"]) : nil,
            updated_at: comment_data["updated_at"] ? Time.parse(comment_data["updated_at"]) : nil,
            issue_id: issue_id,
            adapter_source: :github,
            raw_data: comment_data
          )
        end

        # Maps a pull request to an issue for compatibility
        # @param pull_request_data [Hash] Pull request data from webhook
        # @return [ActiveProject::Resources::Issue] Issue representation of the PR
        def map_webhook_pull_request_to_issue(pull_request_data)
          return nil unless pull_request_data

          # Get state from PR data
          state = pull_request_data["state"]
          status = @config.status_mappings[state] || (state == "open" ? :open : :closed)

          # Extract assignees if present
          assignees = []
          if pull_request_data["assignees"]
            assignees = pull_request_data["assignees"].map do |assignee|
              Resources::User.new(
                self,
                id: assignee["id"].to_s,
                name: assignee["login"],
                adapter_source: :github,
                raw_data: assignee
              )
            end
          end

          # Extract reporter (user who created the PR)
          reporter = nil
          if pull_request_data["user"]
            reporter = Resources::User.new(
              self,
              id: pull_request_data["user"]["id"].to_s,
              name: pull_request_data["user"]["login"],
              adapter_source: :github,
              raw_data: pull_request_data["user"]
            )
          end

          # Determine project ID
          project_id = pull_request_data.dig("base", "repo", "full_name") ||
                      "#{@config.options[:owner]}/#{@config.options[:repo]}"

          # Create an issue resource from the PR data
          Resources::Issue.new(
            self,
            id: pull_request_data["id"].to_s,
            key: pull_request_data["number"].to_s,
            title: pull_request_data["title"],
            description: pull_request_data["body"],
            status: status,
            assignees: assignees,
            reporter: reporter,
            project_id: project_id,
            created_at: pull_request_data["created_at"] ? Time.parse(pull_request_data["created_at"]) : nil,
            updated_at: pull_request_data["updated_at"] ? Time.parse(pull_request_data["updated_at"]) : nil,
            adapter_source: :github,
            raw_data: pull_request_data
          )
        end
      end
    end
  end
end
