# ActiveProject Gem

A standardized Ruby interface for multiple project-management APIs  
(Jira, Basecamp, Trello, GitHub Projects, …).

## Problem

Every platform—Jira, Basecamp, Trello, GitHub—ships its **own** authentication flow, error vocabulary, data model, and workflow quirks.  
Teams end up maintaining a grab-bag of fragile, bespoke clients.

## Solution

ActiveProject wraps those APIs behind a single, opinionated interface:

| Feature | What you get |
|---------|--------------|
| **Normalized models** | `Project`, `Issue` (Task/Card/To-do), `Comment`, `User`—same Ruby objects everywhere. |
| **Standard CRUD** | `issue.close!`, `issue.reopen!`, `project.list_issues`, etc. |
| **Unified errors** | `AuthenticationError`, `NotFoundError`, `RateLimitError`, … regardless of the backend. |
| **Co-operative concurrency** | Fiber-based I/O (via [`async`](https://github.com/socketry/async)) for painless parallel fan-out. |


## Supported Platforms (initial wave)

| Platform                  | API        | Notes                        |
|---------------------------|------------|------------------------------|
| **Jira** (Cloud & Server) | REST v3    | Full issue & project support |
| **Basecamp**              | REST v3+   | Maps To-dos ↔ Issues         |
| **Trello**                | REST       | Cards ↔ Issues               |
| **GitHub Projects V2**    | GraphQL v4 |                              |
| **GitHub**                | REST v3    | Issues and repositories      |

_Planned next_: Asana, Monday.com, Linear, etc.

## Core Concepts

* **Project** – Jira Project, Basecamp Project, Trello Board, GitHub ProjectV2, or GitHub Repository.  
* **Issue** – Unified wrapper around Jira Issue, Basecamp To-do, Trello Card, GitHub Issue/PR.  
  *GitHub DraftIssues intentionally omitted for now.*  
* **Status** – Normalized to `:open`, `:in_progress`, `:blocked`, `:on_hold`, `:closed`.  
* **Priority** – Normalized to `:low`, `:medium`, `:high` (where supported).

---

## Architecture

```

ActiveProject
└── Adapters
  ├── JiraAdapter
  ├── BasecampAdapter
  ├── TrelloAdapter
  ├── GithubProjectAdapter
  └── GithubAdapter

````
Add a new platform by subclassing and conforming to the common contract.
---

## Planned Features

* Webhook helpers for real-time updates  
* Centralised credential/config store  
* Mermaid diagrams for docs & SDK flow-charts  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activeproject'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install activeproject
```

## Usage

### Configuration

Configure multiple adapters, optionally with named instances (default is `:primary`):

```ruby
ActiveProject.configure do |config|
  config.add_adapter :jira,
    site_url:  ENV["JIRA_SITE_URL"],
    username:  ENV["JIRA_USERNAME"],
    api_token: ENV["JIRA_API_TOKEN"]

  config.add_adapter :basecamp,
    account_id:   ENV["BASECAMP_ACCOUNT_ID"],
    access_token: ENV["BASECAMP_ACCESS_TOKEN"]

  config.add_adapter :trello,
    key:   ENV["TRELLO_KEY"],
    token: ENV["TRELLO_TOKEN"]

  # GitHub Projects – real Issues/PRs only
  config.add_adapter :github_project,
    access_token: ENV["GITHUB_TOKEN"]
  
  # GitHub primary instance
  config.add_adapter :github,
    owner: ENV["GITHUB_OWNER"],
    repo: ENV["GITHUB_REPO"],
    access_token: ENV["GITHUB_ACCESS_TOKEN"],
    webhook_secret: ENV["GITHUB_WEBHOOK_SECRET"]
end
```

### Accessing adapters

Fetch a specific adapter instance:

```ruby
jira_primary = ActiveProject.adapter(:jira) # defaults to :primary
jira_secondary = ActiveProject.adapter(:jira, :secondary)
basecamp = ActiveProject.adapter(:basecamp) # defaults to :primary
trello = ActiveProject.adapter(:trello) # defaults to :primary
github = ActiveProject.adapter(:github) # defaults to :primary
github_project = ActiveProject.adapter(:github_project) # defaults to :primary
```

### Basic Usage (Jira Example)

```ruby
# Get the configured Jira adapter instance
jira_adapter = ActiveProject.adapter(:jira)

begin
  # List projects
  projects = jira_adapter.list_projects
  puts "Found #{projects.count} projects."
  first_project = projects.first

  if first_project
    puts "Listing issues for project: #{first_project.key}"
    # List issues in the first project
    issues = jira_adapter.list_issues(first_project.key, max_results: 5)
    puts "- Found #{issues.count} issues (showing max 5)."

    # Find a specific issue (replace 'PROJ-1' with a valid key)
    # issue_key_to_find = 'PROJ-1'
    # issue = jira_adapter.find_issue(issue_key_to_find)
    # puts "- Found issue: #{issue.key} - #{issue.title}"

    # Create a new issue
    puts "Creating a new issue..."
    new_issue_attributes = {
      project: { key: first_project.key },
      summary: "New task from ActiveProject Gem #{Time.now}",
      issue_type: { name: 'Task' }, # Ensure 'Task' is a valid issue type name
      description: "This issue was created via the ActiveProject gem."
    }
    created_issue = jira_adapter.create_issue(first_project.key, new_issue_attributes)
    puts "- Created issue: #{created_issue.key} - #{created_issue.title}"

    # Update the issue
    puts "Updating issue #{created_issue.key}..."
    updated_issue = jira_adapter.update_issue(created_issue.key, { summary: "[Updated] #{created_issue.title}" })
    puts "- Updated summary: #{updated_issue.title}"

    # Add a comment
    puts "Adding comment to issue #{updated_issue.key}..."
    comment = jira_adapter.add_comment(updated_issue.key, "This is a comment added via the ActiveProject gem.")
    puts "- Comment added with ID: #{comment.id}"
  end

rescue ActiveProject::AuthenticationError => e
  puts "Error: Jira Authentication Failed - #{e.message}"
rescue ActiveProject::NotFoundError => e
  puts "Error: Resource Not Found - #{e.message}"
rescue ActiveProject::ValidationError => e
  puts "Error: Validation Failed - #{e.message} (Details: #{e.errors})"
rescue ActiveProject::ApiError => e
  puts "Error: Jira API Error (#{e.status_code}) - #{e.message}"
rescue => e
  puts "An unexpected error occurred: #{e.message}"
end
```

### Basic Usage (Basecamp Example)

```ruby
# Get the configured Basecamp adapter instance
basecamp_adapter = ActiveProject.adapter(:basecamp)

begin
  # List projects
  projects = basecamp_adapter.list_projects
  puts "Found #{projects.count} Basecamp projects."
  first_project = projects.first

  if first_project
    puts "Listing issues (To-dos) for project: #{first_project.name} (ID: #{first_project.id})"
    # List issues (To-dos) in the first project
    # Note: This lists across all to-do lists in the project
    issues = basecamp_adapter.list_issues(first_project.id)
    puts "- Found #{issues.count} To-dos."

    # Create a new issue (To-do)
    # IMPORTANT: You need a valid todolist_id for the target project.
    # You might need another API call to find a todolist_id first.
    # todolist_id_for_test = 1234567 # Replace with a real ID
    # puts "Creating a new To-do..."
    # new_issue_attributes = {
    #   todolist_id: todolist_id_for_test,
    #   title: "New BC To-do from ActiveProject Gem #{Time.now}",
    #   description: "<em>HTML description</em> for the to-do."
    # }
    # created_issue = basecamp_adapter.create_issue(first_project.id, new_issue_attributes)
    # puts "- Created To-do: #{created_issue.id} - #{created_issue.title}"

    # --- Operations requiring project_id context (Currently raise NotImplementedError) ---
    # puts "Finding, updating, and commenting require project_id context and are currently not directly usable via the base interface."
    #
    # # Find a specific issue (To-do) - Requires project_id context
    # # todo_id_to_find = created_issue.id
    # # issue = basecamp_adapter.find_issue(todo_id_to_find) # Raises NotImplementedError
    #
    # # Update the issue (To-do) - Requires project_id context
    # # updated_issue = basecamp_adapter.update_issue(created_issue.id, { title: "[Updated] #{created_issue.title}" }) # Raises NotImplementedError
    #
    # # Add a comment - Requires project_id context
    # # comment = basecamp_adapter.add_comment(created_issue.id, "This is an <b>HTML</b> comment.") # Raises NotImplementedError

  end

rescue ActiveProject::AuthenticationError => e
  puts "Error: Basecamp Authentication Failed - #{e.message}"
rescue ActiveProject::NotFoundError => e
  puts "Error: Basecamp Resource Not Found - #{e.message}"
rescue ActiveProject::ValidationError => e
  puts "Error: Basecamp Validation Failed - #{e.message}"
rescue ActiveProject::RateLimitError => e
  puts "Error: Basecamp Rate Limit Exceeded - #{e.message}"
rescue ActiveProject::ApiError => e
  puts "Error: Basecamp API Error (#{e.status_code}) - #{e.message}"
rescue NotImplementedError => e
  puts "Error: Method requires project_id context which is not yet implemented: #{e.message}"
rescue => e
  puts "An unexpected error occurred: #{e.message}"
end
```

## Asynchronous I/O

ActiveProject ships with `async-http` under the hood.  
Enable the non-blocking adapter by setting an ENV var **before** your process boots:

```bash
AP_DEFAULT_ADAPTER=async_http
```

```ruby
ActiveProject::Async.run do |task|
  jira    = ActiveProject.adapter(:jira)
  boards  = %w[ACME DEV OPS]

  tasks = boards.map do |key|
    task.async { jira.list_issues(key, max_results: 100) }
  end

  issues = tasks.flat_map(&:wait)
  puts "Fetched #{issues.size} issues in parallel."
end
```

No threads, no Mutexes—just Ruby fibers.

---

## Rails auto-scheduler

If your app runs on Rails, ActiveProject’s Railtie installs `Async::Scheduler` automatically **before Zeitwerk boots**.

* Opt out per app:

  ```ruby
  # config/application.rb
  config.active_project.use_async_scheduler = false
  ```

* …or per environment:

  ```bash
  AP_NO_ASYNC_SCHEDULER=1
  ```

If another gem (e.g. Falcon) already set a scheduler, ActiveProject detects it and does nothing.

---

### Basic Usage (GitHub Example)

```ruby
# Get the configured GitHub adapter instance
github_adapter = ActiveProject.adapter(:github)

begin
  # With GitHub adapter, a repository is treated as a project.
  # The adapter is configured for a specific repository.
  
  # List projects (will return the configured repository)
  projects = github_adapter.list_projects
  puts "Found #{projects.count} GitHub repository."
  repo = projects.first
  
  if repo
    puts "Working with repository: #{repo.key} (#{repo.name})"
    
    # List issues in the repository
    issues = github_adapter.list_issues(repo.key)
    puts "- Found #{issues.count} issues."
    
    # Find a specific issue (replace '1' with a valid issue number)
    # issue_number = 1
    # issue = github_adapter.find_issue(issue_number.to_s)
    # puts "- Found issue: ##{issue.key} - #{issue.title}"
    
    # Create a new issue
    puts "Creating a new issue..."
    new_issue_attributes = {
      title: "New issue from ActiveProject Gem #{Time.now}",
      description: "This issue was created via the ActiveProject gem.",
      assignees: [{ name: "username" }]  # Optional: Provide GitHub usernames for assignees
    }
    created_issue = github_adapter.create_issue(repo.key, new_issue_attributes)
    puts "- Created issue: ##{created_issue.key} - #{created_issue.title}"
    
    # Update the issue
    puts "Updating issue ##{created_issue.key}..."
    updated_issue = github_adapter.update_issue(created_issue.key, { title: "[Updated] #{created_issue.title}" })
    puts "- Updated title: #{updated_issue.title}"
    
    # Add a comment
    puts "Adding comment to issue ##{updated_issue.key}..."
    comment = github_adapter.add_comment(updated_issue.key, "This is a comment added via the ActiveProject gem.")
    puts "- Comment added with ID: #{comment.id}"
    
    # Close the issue
    puts "Closing issue ##{updated_issue.key}..."
    closed_issue = github_adapter.update_issue(updated_issue.key, { state: "closed" })
    puts "- Issue closed, status: #{closed_issue.status}"
  end

rescue ActiveProject::AuthenticationError => e
  puts "Error: GitHub Authentication Failed - #{e.message}"
rescue ActiveProject::NotFoundError => e
  puts "Error: Resource Not Found - #{e.message}"
rescue ActiveProject::ValidationError => e
  puts "Error: Validation Failed - #{e.message}"
rescue ActiveProject::RateLimitError => e
  puts "Error: GitHub Rate Limit Exceeded - #{e.message}"
rescue ActiveProject::ApiError => e
  puts "Error: GitHub API Error (#{e.status_code}) - #{e.message}"
rescue => e
  puts "An unexpected error occurred: #{e.message}"
end
```

### Webhook Support (GitHub Example)

The GitHub adapter includes support for processing GitHub webhooks, which allows you to receive real-time events when issues are created, updated, commented on, etc.

```ruby
# Configure the adapter with a webhook secret (same secret used in GitHub webhook settings)
ActiveProject.configure do |config|
  config.add_adapter(:github,
    owner: ENV.fetch('GITHUB_OWNER'),
    repo: ENV.fetch('GITHUB_REPO'),
    access_token: ENV.fetch('GITHUB_ACCESS_TOKEN'),
    webhook_secret: ENV.fetch('GITHUB_WEBHOOK_SECRET', nil)
  )
end

# In your webhook endpoint (e.g., in a Rails controller)
def github_webhook
  adapter = ActiveProject.adapter(:github)
  
  # Get the raw request body and signature header
  request_body = request.raw_post
  signature = request.headers['X-Hub-Signature-256']
  
  # Verify the webhook signature (if webhook_secret is configured)
  if adapter.verify_webhook_signature(request_body, signature)
    # Parse the webhook payload into a standardized WebhookEvent
    event_headers = {
      'X-GitHub-Event' => request.headers['X-GitHub-Event'],
      'X-GitHub-Delivery' => request.headers['X-GitHub-Delivery']
    }
    
    webhook_event = adapter.parse_webhook(request_body, event_headers)
    
    if webhook_event
      # Process different event types
      case webhook_event.type
      when :issue_created
        issue = webhook_event.data[:issue]
        puts "New issue created: ##{issue.key} - #{issue.title}"
        
      when :issue_updated, :issue_closed, :issue_reopened
        issue = webhook_event.data[:issue]
        puts "Issue ##{issue.key} was #{webhook_event.type.to_s.sub('issue_', '')}"
        
      when :comment_created
        comment = webhook_event.data[:comment]
        issue = webhook_event.data[:issue]
        puts "New comment on issue ##{issue.key}: #{comment.body.truncate(50)}"
      end
      
      # The webhook was successfully processed
      head :ok
    else
      # The webhook payload couldn't be parsed
      head :unprocessable_entity
    end
  else
    # The webhook signature verification failed
    head :forbidden
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/active_project/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [RubyGems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/active_project.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
