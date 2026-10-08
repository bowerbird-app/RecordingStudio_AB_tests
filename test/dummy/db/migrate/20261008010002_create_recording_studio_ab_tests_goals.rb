# frozen_string_literal: true

class CreateRecordingStudioAbTestsGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_goals, id: :uuid do |t|
      t.uuid :experiment_id, null: false
      t.string :key, null: false
      t.string :name, null: false
      t.string :event_key, null: false
      t.boolean :is_primary, null: false, default: false
      t.integer :attribution_window_hours, null: false, default: 168
      t.string :counting_policy, null: false, default: "once_per_participant"

      t.timestamps
    end

    add_index :recording_studio_ab_tests_goals, %i[experiment_id key], unique: true,
              name: "idx_rsab_goals_experiment_key"
    add_index :recording_studio_ab_tests_goals, :experiment_id, unique: true,
              where: "is_primary = TRUE",
              name: "idx_rsab_goals_primary"
    add_index :recording_studio_ab_tests_goals, :event_key, name: "idx_rsab_goals_event_key"

    add_check_constraint :recording_studio_ab_tests_goals,
                         "attribution_window_hours >= 1 AND attribution_window_hours <= 2160",
                         name: "chk_rsab_goals_window"
    add_check_constraint :recording_studio_ab_tests_goals,
                         "counting_policy IN ('once_per_participant', 'every_event')",
                         name: "chk_rsab_goals_counting"

    add_foreign_key :recording_studio_ab_tests_goals, :recording_studio_ab_tests_experiments,
                    column: :experiment_id, on_delete: :cascade
  end
end
