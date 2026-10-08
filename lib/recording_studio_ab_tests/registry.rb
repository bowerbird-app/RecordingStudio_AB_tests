# frozen_string_literal: true

module RecordingStudioAbTests
  class Registry
    def initialize
      @targets = {}
      @events = {}
      @mutex = Mutex.new
    end

    def register_target(key, **)
      target = Target.new(key, **)
      @mutex.synchronize { @targets[target.key] = target }
      target
    end

    def register_event(key, **)
      event = EventDefinition.new(key, **)
      @mutex.synchronize { @events[event.key] = event }
      event
    end

    def target(key)
      @targets[key.to_sym]
    end

    def fetch_target!(key)
      target(key) || raise(UnknownTarget, "unknown AB target #{key.inspect}")
    end

    def event(key)
      @events[key.to_sym]
    end

    def targets
      @targets.dup
    end

    def events
      @events.dup
    end

    def clear!
      @mutex.synchronize do
        @targets = {}
        @events = {}
      end
    end
  end
end
