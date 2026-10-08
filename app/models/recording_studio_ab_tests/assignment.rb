# frozen_string_literal: true

module RecordingStudioAbTests
  class Assignment < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_assignments"

    SUBJECT_TYPES = %w[visitor user root_recording].freeze

    belongs_to :experiment, class_name: "RecordingStudioAbTests::Experiment",
                            inverse_of: :assignments
    belongs_to :variant, class_name: "RecordingStudioAbTests::Variant"

    has_many :exposures, class_name: "RecordingStudioAbTests::Exposure",
                         foreign_key: :assignment_id, inverse_of: :assignment, dependent: :restrict_with_exception
    has_many :conversions, class_name: "RecordingStudioAbTests::Conversion",
                           foreign_key: :assignment_id, inverse_of: :assignment, dependent: :restrict_with_exception

    validates :subject_type, presence: true, inclusion: { in: SUBJECT_TYPES }
    validates :subject_identifier, presence: true
    validates :allocation_version, presence: true
    validates :bucket, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 9999 }
    validates :assigned_at, presence: true
    validate :only_link_columns_change, on: :update

    private

    def only_link_columns_change
      allowed = %w[linked_user_id linked_at link_source promoted_from_assignment_id updated_at]
      changed = changes.keys - allowed
      return if changed.empty?

      errors.add(:base, "assignments are immutable except linked_* columns (changed: #{changed.join(', ')})")
    end
  end
end
