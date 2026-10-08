# frozen_string_literal: true

class CreateRecordingStudioAbTestsExperiments < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_experiments, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.string :target_key, null: false
      t.string :assignment_scope, null: false
      t.integer :traffic_percentage, null: false, default: 100
      t.string :allocation_seed, null: false
      t.string :allocation_version, null: false, default: "sha256-v1"
      t.uuid :scope_root_recording_id
      t.uuid :winner_variant_id
      t.datetime :started_at
      t.datetime :paused_at
      t.datetime :completed_at
      t.datetime :archived_at
      t.string :created_by_type
      t.uuid :created_by_id
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :recording_studio_ab_tests_experiments, :key, unique: true, name: "idx_rsab_experiments_key"
    add_index :recording_studio_ab_tests_experiments, %i[target_key status], name: "idx_rsab_experiments_target_status"
    add_index :recording_studio_ab_tests_experiments, :target_key, unique: true,
              where: "status IN ('running', 'paused')",
              name: "idx_rsab_experiments_live_target"

    add_check_constraint :recording_studio_ab_tests_experiments,
                         "status IN ('draft', 'running', 'paused', 'completed', 'archived')",
                         name: "chk_rsab_experiments_status"
    add_check_constraint :recording_studio_ab_tests_experiments,
                         "assignment_scope IN ('visitor', 'user', 'root_recording')",
                         name: "chk_rsab_experiments_scope"
    add_check_constraint :recording_studio_ab_tests_experiments,
                         "traffic_percentage >= 0 AND traffic_percentage <= 100",
                         name: "chk_rsab_experiments_traffic"

    add_foreign_key :recording_studio_ab_tests_experiments, :recording_studio_recordings,
                    column: :scope_root_recording_id, validate: false
  end
end
