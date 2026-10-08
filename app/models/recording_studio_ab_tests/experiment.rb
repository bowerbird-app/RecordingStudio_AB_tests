# frozen_string_literal: true

module RecordingStudioAbTests
  class Experiment < ApplicationRecord
    self.table_name = "recording_studio_ab_tests_experiments"

    STATUSES = %w[draft running paused completed archived].freeze
    SCOPES = %w[visitor user root_recording].freeze
    KEY_FORMAT = /\A[a-z][a-z0-9_]{1,62}\z/

    belongs_to :created_by, polymorphic: true, optional: true
    belongs_to :winner_variant, class_name: "RecordingStudioAbTests::Variant", optional: true

    has_many :variants, class_name: "RecordingStudioAbTests::Variant",
                        foreign_key: :experiment_id, inverse_of: :experiment, dependent: :destroy
    has_many :goals, class_name: "RecordingStudioAbTests::Goal",
                     foreign_key: :experiment_id, inverse_of: :experiment, dependent: :destroy
    has_many :assignments, class_name: "RecordingStudioAbTests::Assignment",
                           foreign_key: :experiment_id, inverse_of: :experiment, dependent: :restrict_with_exception
    has_many :exposures, class_name: "RecordingStudioAbTests::Exposure",
                         foreign_key: :experiment_id, inverse_of: :experiment, dependent: :restrict_with_exception
    has_many :conversions, class_name: "RecordingStudioAbTests::Conversion",
                           foreign_key: :experiment_id, inverse_of: :experiment, dependent: :restrict_with_exception

    validates :key, presence: true, uniqueness: true, format: { with: KEY_FORMAT }
    validates :name, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :target_key, presence: true
    validates :assignment_scope, presence: true, inclusion: { in: SCOPES }
    validates :traffic_percentage, presence: true,
                                   numericality: {
                                     only_integer: true,
                                     greater_than_or_equal_to: 0,
                                     less_than_or_equal_to: 100
                                   }
    validates :allocation_seed, presence: true
    validates :allocation_version, presence: true

    before_validation :ensure_allocation_seed, on: :create
    validate :frozen_fields_unchanged, on: :update

    after_commit :bump_active_set

    def started?
      !draft? && !status.nil?
    end

    def draft?
      status == "draft"
    end

    def running?
      status == "running"
    end

    def paused?
      status == "paused"
    end

    def completed?
      status == "completed"
    end

    def archived?
      status == "archived"
    end

    private

    def ensure_allocation_seed
      self.allocation_seed = SecureRandom.hex(8) if allocation_seed.blank?
    end

    def frozen_fields_unchanged
      return if status_was.blank? || status_was == "draft"

      Lifecycle::FROZEN_AFTER_START.each do |attr|
        next unless will_save_change_to_attribute?(attr)

        errors.add(attr, "cannot change after experiment has started")
      end
    end

    def bump_active_set
      ActiveSet.bump!
    end
  end
end
