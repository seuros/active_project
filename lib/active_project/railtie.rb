# frozen_string_literal: true

require "rails/railtie"
require "async" # async is now a hard dependency

module ActiveProject
  class Railtie < ::Rails::Railtie
    config.active_project = ActiveSupport::OrderedOptions.new
    # Host apps may override this in application.rb:
    #   config.active_project.use_async_scheduler = false
    config.active_project.use_async_scheduler = true

    # We run BEFORE Zeitwerk starts autoloading so that
    # every thread inherits the scheduler.
    initializer "active_project.set_async_scheduler",
                before: :initialize_dependency_mechanism do |app|
      # 1. Allow opt-out
      next unless app.config.active_project.use_async_scheduler
      next if ENV["AP_NO_ASYNC_SCHEDULER"] == "1"

      # 2. Don’t clobber a scheduler the host already set
      next if Fiber.scheduler

      # 3. Install Async’s cooperative scheduler
      Fiber.set_scheduler ::Async::Scheduler.new

      ActiveSupport::Notifications.instrument(
        "active_project.async_scheduler_set",
        scheduler: Fiber.scheduler.class.name
      )
    end
  end
end
