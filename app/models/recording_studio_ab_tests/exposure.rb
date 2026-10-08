# frozen_string_literal: true

module RecordingStudioAbTests
  class Exposure < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_exposures"

    MAX_METADATA_BYTES = 2 * 1024

    belongs_to :experiment, class_name: "RecordingStudioAbTests::Experiment",
                            inverse_of: :exposures
    belongs_to :variant, class_name: "RecordingStudioAbTests::Variant"
    belongs_to :assignment, class_name: "RecordingStudioAbTests::Assignment",
                            inverse_of: :exposures

    validates :target_key, presence: true
    validates :first_exposed_at, presence: true
    validates :last_exposed_at, presence: true
    validates :exposure_count, presence: true,
                               numericality: { only_integer: true, greater_than: 0 }
    validate :metadata_size

    private

    def metadata_size
      return if metadata.nil?

      bytes = metadata.to_json.bytesize
      return if bytes <= MAX_METADATA_BYTES

      errors.add(:metadata, "exceeds #{MAX_METADATA_BYTES} bytes")
    end
  end
end
