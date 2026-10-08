# frozen_string_literal: true

module RecordingStudioAbTests
  class Goal < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_goals"

    COUNTING_POLICIES = %w[once_per_participant every_event].freeze

    belongs_to :experiment, class_name: "RecordingStudioAbTests::Experiment",
                            inverse_of: :goals

    validates :key, presence: true, uniqueness: { scope: :experiment_id }
    validates :name, presence: true
    validates :event_key, presence: true
    validates :attribution_window_hours, presence: true,
                                         numericality: {
                                           only_integer: true,
                                           greater_than_or_equal_to: 1,
                                           less_than_or_equal_to: 2160
                                         }
    validates :counting_policy, presence: true, inclusion: { in: COUNTING_POLICIES }
    validate :primary_event_immutable_after_start

    after_commit :bump_active_set

    private

    def primary_event_immutable_after_start
      return unless experiment
      return if experiment.draft?
      return unless is_primary?
      return unless will_save_change_to_event_key?

      errors.add(:event_key, "primary goal event is frozen after start")
    end

    def bump_active_set
      ActiveSet.bump!
    end
  end
end
