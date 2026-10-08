# frozen_string_literal: true

class CreateRecordingStudioAbTestsConversions < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_conversions, id: :uuid do |t|
      t.uuid :experiment_id, null: false
      t.uuid :variant_id, null: false
      t.uuid :assignment_id, null: false
      t.uuid :goal_id, null: false
      t.string :source_event_key, null: false
      t.string :source_event_id
      t.string :idempotency_key, null: false
      t.datetime :occurred_at, null: false
      t.decimal :value, precision: 18, scale: 4
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :recording_studio_ab_tests_conversions, :idempotency_key, unique: true,
                                                                        name: "idx_rsab_conversions_idem"
    add_index :recording_studio_ab_tests_conversions, %i[experiment_id goal_id variant_id],
              name: "idx_rsab_conversions_experiment_goal_variant"
    add_index :recording_studio_ab_tests_conversions, %i[assignment_id goal_id],
              name: "idx_rsab_conversions_assignment_goal"

    add_foreign_key :recording_studio_ab_tests_conversions, :recording_studio_ab_tests_experiments,
                    column: :experiment_id
    add_foreign_key :recording_studio_ab_tests_conversions, :recording_studio_ab_tests_variants,
                    column: :variant_id
    add_foreign_key :recording_studio_ab_tests_conversions, :recording_studio_ab_tests_assignments,
                    column: :assignment_id
    add_foreign_key :recording_studio_ab_tests_conversions, :recording_studio_ab_tests_goals,
                    column: :goal_id
  end
end
