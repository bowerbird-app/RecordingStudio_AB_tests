# frozen_string_literal: true

module RecordingStudioAbTests
  class Variant < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_variants"

    KEY_FORMAT = /\A[a-z][a-z0-9_]{0,30}\z/

    belongs_to :experiment, class_name: "RecordingStudioAbTests::Experiment",
                            inverse_of: :variants

    validates :key, presence: true, format: { with: KEY_FORMAT },
                    uniqueness: { scope: :experiment_id }
    validates :name, presence: true
    validates :implementation_key, presence: true,
                                   uniqueness: { scope: :experiment_id }
    validates :weight, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :position, presence: true, numericality: { only_integer: true }
    validate :control_immutable_after_start
    validate :variant_set_immutable_after_start, on: :create

    after_commit :bump_active_set

    private

    def control_immutable_after_start
      return unless experiment
      return if experiment.draft?
      unless will_save_change_to_is_control? || will_save_change_to_implementation_key? || will_save_change_to_key?
        return
      end

      errors.add(:base, "variant identity is frozen after start")
    end

    def variant_set_immutable_after_start
      return unless experiment
      return if experiment.draft?

      errors.add(:base, "cannot add variants after start")
    end

    def bump_active_set
      ActiveSet.bump!
    end
  end
end
