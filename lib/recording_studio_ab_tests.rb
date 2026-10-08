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
require "recording_studio_ab_tests/metrics"
require "recording_studio_ab_tests/exposer"
require "recording_studio_ab_tests/conversion_recorder"
require "recording_studio_ab_tests/identity_linker"
require "recording_studio_ab_tests/event_subscriptions"
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

    # Registers the built-in user_registered event when subscribe_to_user_registration.
    def register_builtin_events!
      EventSubscriptions.install!
    end

    # subject: is reserved for authenticated/out-of-request subjects (PR4).
    def execute(target_key, subject: nil, **)
      _ = subject
      target = registry.fetch_target!(target_key)
      raise NotImplementedError, "service adapter lands in PR4" if target.type == :service

      raise ArgumentError, "execute only supports service targets (got #{target.type})"
    end

    # Records exposure for hosts that render the implementation themselves.
    # subject: reserved for out-of-request exposure (PR4).
    def expose(target_key, subject: nil)
      _ = subject
      AssignmentResolver.resolve(target_key, expose: true)
    end

    def track_event(event_key, subject:, event_id: nil, value: nil, occurred_at: Time.current, metadata: {})
      kind, identifier = resolve_event_subject(subject)
      raise ArgumentError, "track_event requires a subject" if kind.nil? || identifier.blank?

      attrs = {
        event_key: event_key,
        subject_kind: kind,
        subject_identifier: identifier,
        event_id: event_id,
        value: value,
        occurred_at: occurred_at || Time.current,
        metadata: metadata || {}
      }

      ActiveRecord.after_all_transactions_commit do
        ConversionRecorder.record!(**attrs)
      end
    end

    def link_identity(visitor_id:, user:, source:)
      IdentityLinker.link!(visitor_id: visitor_id, user: user, source: source)
    end

    def current_visitor_id
      Identity.visitor_id(create: false)
    end

    def visitor(id)
      Struct.new(:id, :ab_subject_kind).new(id, :visitor)
    end

    private

    def resolve_event_subject(subject)
      return [nil, nil] if subject.nil?

      return [:visitor, subject.id.to_s] if subject.respond_to?(:ab_subject_kind) && subject.ab_subject_kind == :visitor

      if defined?(RecordingStudio::Recording) && subject.is_a?(RecordingStudio::Recording)
        return [:root_recording, subject.id.to_s]
      end

      return [:user, configuration.user_identifier.call(subject).to_s] if subject.respond_to?(:id)

      [:user, subject.to_s]
    end
  end
end
