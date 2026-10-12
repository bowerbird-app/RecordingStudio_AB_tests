# frozen_string_literal: true

module RecordingStudioAbTests
  class Conversion < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_conversions"

    MAX_METADATA_BYTES = 2 * 1024

    belongs_to :experiment, class_name: "RecordingStudioAbTests::Experiment",
                            inverse_of: :conversions
    belongs_to :variant, class_name: "RecordingStudioAbTests::Variant"
    belongs_to :assignment, class_name: "RecordingStudioAbTests::Assignment",
                            inverse_of: :conversions
    belongs_to :goal, class_name: "RecordingStudioAbTests::Goal"

    validates :source_event_key, presence: true
    validates :idempotency_key, presence: true, uniqueness: true
    validates :occurred_at, presence: true
    validate :metadata_size

    private

    def metadata_size
      return if metadata.nil?

      bytes = metadata.to_json.bytesize
      return if bytes <= MAX_METADATA_BYTES

      # ActiveModel 8.1 ignores message: when the type is a String, so the
      # resolved Copy.t string is the type (English stays byte-identical to main).
      errors.add(
        :metadata,
        Copy.t("errors.metadata_too_large", default: "exceeds %{max} bytes", max: MAX_METADATA_BYTES)
      )
    end
  end
end
