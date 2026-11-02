# frozen_string_literal: true

module RecordingStudioAbTests
  # Persists server-side exposures through RecordExposureJob (async or inline).
  module Exposer
    module_function

    def record!(entry:, target_key:, resolution:)
      return unless resolution

      memo_key = "#{entry[:id]}:#{target_key}"
      return if Current.exposed.include?(memo_key)

      # Cookie target list only proves a prior request already exposed this target.
      # Same-request write_cookie_from! also adds the target, so only trust the
      # cookie list on a cookie-hit resolution (returning visitor).
      if resolution.reason == :cookie && cookie_already_exposed?(entry, target_key)
        Current.exposed << memo_key
        return
      end

      assignment = resolution.assignment || find_assignment(entry)
      return unless assignment

      Current.exposed << memo_key
      mark_cookie_exposed!(entry, target_key, resolution, assignment)

      args = {
        assignment_id: assignment.id,
        target_key: target_key.to_s,
        request_id: Current.request&.request_id,
        metadata: {},
        exposed_at: Time.current.iso8601(6)
      }

      if RecordingStudioAbTests.configuration.exposure_mode.to_sym == :inline
        RecordExposureJob.perform_now(**args)
      else
        RecordExposureJob.perform_later(**args)
      end
    rescue StandardError => e
      ActiveSupport::Notifications.instrument(
        "exposure_failed.recording_studio_ab_tests",
        error: e,
        target_key: target_key,
        experiment_id: entry[:id]
      )
      raise if RecordingStudioAbTests.configuration.raise_errors
    end

    def cookie_already_exposed?(entry, target_key)
      request = Current.request
      return false unless request

      payload = CookieCodec.read(request)
      data = CookieCodec.entry_for(payload, entry[:id])
      return false unless data.is_a?(Array) && data[1].is_a?(Array)

      data[1].include?(target_key.to_s)
    end

    def mark_cookie_exposed!(entry, target_key, resolution, assignment)
      request = Current.request
      return unless request
      return unless assignment.subject_type == "visitor"

      payload = CookieCodec.read(request)
      payload = CookieCodec.put_entry(
        payload,
        experiment_id: entry[:id],
        variant_key: resolution.variant_key,
        target_key: target_key,
        visitor_id: assignment.subject_identifier
      )
      active_ids = ActiveSet.current[:by_target].values.map { |e| e[:id] }
      payload = CookieCodec.evict!(payload, active_experiment_ids: active_ids)
      CookieCodec.write!(request, payload)
    end

    def find_assignment(entry)
      subject = Identity.resolve_subject(
        AssignmentResolver::OpenStructExperiment.new(entry),
        create_visitor: false
      )
      return nil unless subject

      Assignment.find_by(
        experiment_id: entry[:id],
        subject_type: subject[:subject_type],
        subject_identifier: subject[:subject_identifier]
      )
    end
  end
end
