# frozen_string_literal: true

require_relative 'lib/active_project/version'

Gem::Specification.new do |spec|
  spec.name        = 'activeproject'
  spec.version     = ActiveProject::VERSION
  spec.authors     = [ 'Abdelkader Boudih' ]
  spec.email       = [ 'terminale@gmail.com' ]
  spec.homepage    = 'https://github.com/seuros/active_project'
  spec.summary     = 'A standardized Ruby interface for multiple project management APIs (Jira, Basecamp, Trello, etc.).'
  spec.description = 'Provides a unified API client for interacting with various project management platforms like Jira, Basecamp, and Trello. Aims to normalize core models (projects, tasks, comments) and workflows for easier integration in Rails applications.'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/seuros/active_project'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['lib/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activesupport', '>= 8.0', '< 9.0'
  spec.add_dependency 'async', '>= 2.35'
  spec.add_dependency 'async-http', '>= 0.92'
  spec.add_dependency 'async-http-faraday', '>= 0.22'
  spec.add_dependency 'concurrent-ruby', '>= 1.2'
  spec.add_dependency 'faraday', '>= 2.0'
  spec.add_dependency 'faraday-retry'
  spec.add_development_dependency 'async-safe'
  spec.add_development_dependency 'mocha'
end
