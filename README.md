# ActiveProject Gem

A standardized Ruby interface for multiple project management APIs (Jira, Basecamp, Trello, etc.).

## Problem

Integrating with various project management platforms like Jira, Basecamp, and Trello often requires writing separate, complex clients for each API. Developers face challenges in handling different authentication methods, error formats, data structures, and workflow concepts across these platforms.

## Solution

The ActiveProject gem aims to solve this by providing a unified, opinionated interface built on the **Adapter pattern**. It abstracts away the complexities of individual APIs, offering:

*   **Normalized Data Models:** Common Ruby objects for core concepts like `Project`, `Task` (Issue/Card/To-do), `Comment`, and `User`.
*   **Standardized Operations:** Consistent methods for creating, reading, updating, and transitioning tasks (e.g., `task.close!`, `task.reopen!`).
*   **Unified Error Handling:** A common set of exceptions (`AuthenticationError`, `NotFoundError`, `RateLimitError`, etc.) regardless of the underlying platform.

## Supported Platforms

The initial focus is on integrating with platforms primarily via their **REST APIs**:

*   **Jira (Cloud & Server):** REST API (v3)
*   **Basecamp (v3+):** REST API
*   **Trello:** REST API

Future integrations might include platforms like Asana (REST), Monday.com (GraphQL), and Linear (GraphQL). For GraphQL-based APIs, the adapter will encapsulate the query logic, maintaining a consistent interface for the gem user.

## Core Concepts

*   **Project:** Represents a Jira Project, Basecamp Project, or Trello Board.
*   **Task:** A unified representation of a Jira Issue, Basecamp To-do, or Trello Card. Includes normalized fields like `title`, `description`, `assignees`, `status`, and `priority`.
*   **Status Normalization:** Maps platform-specific statuses (Jira statuses, Basecamp completion, Trello lists) to a common set like `:open`, `:in_progress`, `:closed`.
*   **Priority Normalization:** Maps priorities (where available, like in Jira) to a standard scale (e.g., `:low`, `:medium`, `:high`).

## Architecture

The gem uses an **Adapter pattern**, with specific adapters (`Adapters::JiraAdapter`, `Adapters::BasecampAdapter`, etc.) implementing a common interface. This allows for easy extension to new platforms.

## Planned Features

*   CRUD operations for Projects and Tasks.
*   Unified status transitions.
*   Comment management.
*   Standardized error handling and reporting.
*   Webhook support for real-time updates from platforms.
*   Configuration management for API credentials.
*   Utilization of **Mermaid diagrams** to visualize workflows and integration logic within documentation.

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
  # Primary Jira instance (default name :primary)
  config.add_adapter(:jira,
    site_url: ENV.fetch('JIRA_SITE_URL'),
    username: ENV.fetch('JIRA_USERNAME'),
    api_token: ENV.fetch('JIRA_API_TOKEN')
  )

  # Secondary Jira instance
  config.add_adapter(:jira, :secondary,
    site_url: ENV.fetch('JIRA_SECOND_SITE_URL'),
    username: ENV.fetch('JIRA_SECOND_USERNAME'),
    api_token: ENV.fetch('JIRA_SECOND_API_TOKEN')
  )

  # Basecamp primary instance
  config.add_adapter(:basecamp,
    account_id: ENV.fetch('BASECAMP_ACCOUNT_ID'),
    access_token: ENV.fetch('BASECAMP_ACCESS_TOKEN')
  )

  # Trello primary instance
  config.add_adapter(:trello,
    key: ENV.fetch('TRELLO_KEY'),
    token: ENV.fetch('TRELLO_TOKEN')
  )
end
```

### Accessing adapters

Fetch a specific adapter instance:

```ruby
jira_primary = ActiveProject.adapter(:jira) # defaults to :primary
jira_secondary = ActiveProject.adapter(:jira, :secondary)
basecamp = ActiveProject.adapter(:basecamp) # defaults to :primary
trello = ActiveProject.adapter(:trello) # defaults to :primary
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
basecamp_config = ActiveProject.configuration.adapter_config(:basecamp)
basecamp_adapter = ActiveProject::Adapters::BasecampAdapter.new(**basecamp_config)

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/active_project/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [RubyGems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/seuros/active_project.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
