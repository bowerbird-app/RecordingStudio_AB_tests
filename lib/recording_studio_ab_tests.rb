# frozen_string_literal: true

require "recording_studio"
require "recording_studio_ab_tests/version"
require "recording_studio_ab_tests/errors"
require "recording_studio_ab_tests/configuration"
require "recording_studio_ab_tests/current"
require "recording_studio_ab_tests/request_context"
require "recording_studio_ab_tests/target"
require "recording_studio_ab_tests/event_definition"
require "recording_studio_ab_tests/registry"
require "recording_studio_ab_tests/allocator"
require "recording_studio_ab_tests/eligibility"
require "recording_studio_ab_tests/identity"
require "recording_studio_ab_tests/cookie_codec"
require "recording_studio_ab_tests/active_set"
require "recording_studio_ab_tests/assignment_resolver"
require "recording_studio_ab_tests/lifecycle"
require "recording_studio_ab_tests/view_helper"
require "recording_studio_ab_tests/controller_helper"
require "recording_studio_ab_tests/adapters/view"
require "recording_studio_ab_tests/adapters/partial"
require "recording_studio_ab_tests/adapters/component"
require "recording_studio_ab_tests/test_helpers"
require "recording_studio_ab_tests/engine"

module RecordingStudioAbTests
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def registry
      @registry ||= Registry.new
    end

    def register_target(key, **)
      registry.register_target(key, **)
    end

    def register_event(key, **)
      registry.register_event(key, **)
    end

    # subject: is reserved for authenticated/out-of-request subjects (PR4).
    def execute(target_key, subject: nil, **)
      _ = subject
      target = registry.fetch_target!(target_key)
      raise NotImplementedError, "service adapter lands in PR4" if target.type == :service

      raise ArgumentError, "execute only supports service targets (got #{target.type})"
    end

    # subject: is reserved for out-of-request exposure (PR2/PR4).
    def expose(target_key, subject: nil)
      _ = subject
      AssignmentResolver.resolve(target_key, expose: true)
    end

    def track_event(*)
      raise NotImplementedError, "track_event lands in PR2"
    end

    def link_identity(*)
      raise NotImplementedError, "link_identity lands in PR2"
    end

    def current_visitor_id
      Identity.visitor_id(create: false)
    end

    def visitor(id)
      Struct.new(:id).new(id)
    end
  end
end
