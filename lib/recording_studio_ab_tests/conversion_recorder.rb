# frozen_string_literal: true

require "digest"

module RecordingStudioAbTests
  class ConversionRecorder
    class << self
      def record!(event_key:, subject_kind:, subject_identifier:, event_id: nil,
                  value: nil, occurred_at: Time.current, metadata: {})
        event_key = event_key.to_s
        definition = RecordingStudioAbTests.registry.event(event_key)
        unless definition
          handle_unknown_event!(event_key)
          return []
        end

        goals = ActiveSet.current[:goals_by_event][event_key]
        return if goals.blank?

        assignments = candidate_assignments(
          subject_kind: subject_kind,
          subject_identifier: subject_identifier.to_s,
          experiment_ids: goals.map { |g| g[:experiment_id] }.uniq
        )
        return if assignments.empty?

        rows = []
        assignments.each do |assignment|
          goals.select { |g| g[:experiment_id] == assignment.experiment_id }.each do |goal|
            window_end = assignment.assigned_at + goal[:attribution_window_hours].hours
            next unless occurred_at >= assignment.assigned_at && occurred_at <= window_end

            idem = idempotency_key(
              goal: goal,
              assignment: assignment,
              event_key: event_key,
              event_id: event_id
            )
            next if idem.nil?

            rows << {
              id: SecureRandom.uuid,
              experiment_id: assignment.experiment_id,
              variant_id: assignment.variant_id,
              assignment_id: assignment.id,
              goal_id: goal[:goal_id],
              source_event_key: event_key,
              source_event_id: event_id&.to_s,
              idempotency_key: idem,
              occurred_at: occurred_at,
              value: value,
              metadata: sanitize_metadata(metadata),
              created_at: Time.current
            }
          end
        end

        return if rows.empty?

        Conversion.insert_all(rows, unique_by: :idx_rsab_conversions_idem)
        ActiveSupport::Notifications.instrument(
          "conversion.recording_studio_ab_tests",
          event_key: event_key,
          count: rows.size,
          subject_kind: subject_kind,
          subject_identifier: subject_identifier.to_s
        )
      rescue StandardError => e
        ActiveSupport::Notifications.instrument(
          "conversion_failed.recording_studio_ab_tests",
          error: e,
          event_key: event_key
        )
        Rails.logger.error("[RecordingStudioAbTests] conversion failed: #{e.class}: #{e.message}")
        raise if RecordingStudioAbTests.configuration.raise_errors
      end

      private

      def handle_unknown_event!(event_key)
        message = "unknown AB event #{event_key.inspect}"
        raise UnknownEvent, message if raise_on_unknown?

        Rails.logger.warn("[RecordingStudioAbTests] #{message}")
      end

      def raise_on_unknown?
        return true unless defined?(Rails)

        Rails.env.development? || Rails.env.test? || RecordingStudioAbTests.configuration.raise_errors
      end

      def candidate_assignments(subject_kind:, subject_identifier:, experiment_ids:)
        scope = Assignment.where(experiment_id: experiment_ids)
        case subject_kind.to_sym
        when :user
          scope.where(
            "(subject_type = ? AND subject_identifier = ?) OR (subject_type = ? AND linked_user_id = ?)",
            "user", subject_identifier, "visitor", subject_identifier
          )
        when :visitor
          scope.where(subject_type: "visitor", subject_identifier: subject_identifier)
        when :root_recording
          scope.where(subject_type: "root_recording", subject_identifier: subject_identifier)
        else
          Assignment.none
        end.to_a
      end

      def idempotency_key(goal:, assignment:, event_key:, event_id:)
        case goal[:counting_policy]
        when "once_per_participant"
          Digest::SHA256.hexdigest("#{goal[:goal_id]}|#{assignment.id}")
        when "every_event"
          if event_id.blank?
            message = "every_event goal #{goal[:key]} requires event_id"
            raise InvalidEvent, message if raise_on_unknown?

            Rails.logger.warn("[RecordingStudioAbTests] #{message}")
            return nil
          end
          Digest::SHA256.hexdigest("#{goal[:goal_id]}|#{assignment.id}|#{event_key}|#{event_id}")
        else
          Digest::SHA256.hexdigest("#{goal[:goal_id]}|#{assignment.id}")
        end
      end

      def sanitize_metadata(metadata)
        hash = metadata.is_a?(Hash) ? metadata : {}
        json = hash.to_json
        return hash if json.bytesize <= Conversion::MAX_METADATA_BYTES

        Rails.logger.warn("[RecordingStudioAbTests] conversion metadata exceeded 2KB; dropping")
        {}
      end
    end
  end
end
