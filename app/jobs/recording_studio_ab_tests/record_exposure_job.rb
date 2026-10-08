# frozen_string_literal: true

module RecordingStudioAbTests
  class RecordExposureJob < ActiveJob::Base
    queue_as { RecordingStudioAbTests.configuration.exposure_queue }

    def perform(assignment_id:, target_key:, request_id: nil, metadata: {}, exposed_at: nil)
      assignment = Assignment.find_by(id: assignment_id)
      return unless assignment

      now = (exposed_at.presence && Time.zone.parse(exposed_at.to_s)) || Time.current
      meta = sanitize_metadata(metadata)

      if RecordingStudioAbTests.configuration.track_repeat_exposures
        upsert_repeat!(assignment, target_key, request_id, meta, now)
      else
        insert_once!(assignment, target_key, request_id, meta, now)
      end

      ActiveSupport::Notifications.instrument(
        "exposure.recording_studio_ab_tests",
        experiment_id: assignment.experiment_id,
        target_key: target_key,
        variant_id: assignment.variant_id,
        assignment_id: assignment.id
      )
    rescue StandardError => e
      ActiveSupport::Notifications.instrument(
        "exposure_failed.recording_studio_ab_tests",
        error: e,
        assignment_id: assignment_id,
        target_key: target_key
      )
      raise
    end

    private

    def insert_once!(assignment, target_key, request_id, metadata, now)
      Exposure.insert_all(
        [{
          id: SecureRandom.uuid,
          experiment_id: assignment.experiment_id,
          variant_id: assignment.variant_id,
          assignment_id: assignment.id,
          target_key: target_key.to_s,
          first_exposed_at: now,
          last_exposed_at: now,
          exposure_count: 1,
          request_id: request_id,
          metadata: metadata,
          created_at: now,
          updated_at: now
        }],
        unique_by: :idx_rsab_exposures_unique
      )
    end

    def upsert_repeat!(assignment, target_key, request_id, metadata, now)
      existing = Exposure.find_by(assignment_id: assignment.id, target_key: target_key.to_s)
      if existing
        existing.update_columns(
          last_exposed_at: now,
          exposure_count: existing.exposure_count + 1,
          request_id: request_id.presence || existing.request_id,
          updated_at: now
        )
      else
        insert_once!(assignment, target_key, request_id, metadata, now)
      end
    end

    def sanitize_metadata(metadata)
      hash = metadata.is_a?(Hash) ? metadata : {}
      json = hash.to_json
      return hash if json.bytesize <= Exposure::MAX_METADATA_BYTES

      Rails.logger.warn("[RecordingStudioAbTests] exposure metadata exceeded 2KB; dropping")
      {}
    end
  end
end
