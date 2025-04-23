require "async"
Fiber.set_scheduler Async::Scheduler.new
