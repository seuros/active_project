# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in activeproject.gemspec.
gemspec

gem "railties"

gem "puma"

gem "sqlite3"

gem "dotenv-rails", groups: %i[development test]

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

group :test do
  gem "vcr"
  gem "webmock"
end
