# frozen_string_literal: true

class CreateRecordingStudioAbTestsExposures < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_exposures, id: :uuid do |t|
      t.uuid :experiment_id, null: false
      t.uuid :variant_id, null: false
      t.uuid :assignment_id, null: false
      t.string :target_key, null: false
      t.datetime :first_exposed_at, null: false
      t.datetime :last_exposed_at, null: false
      t.integer :exposure_count, null: false, default: 1
      t.string :request_id
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :recording_studio_ab_tests_exposures, %i[assignment_id target_key], unique: true,
                                                                                  name: "idx_rsab_exposures_unique"
    add_index :recording_studio_ab_tests_exposures, %i[experiment_id variant_id first_exposed_at],
              name: "idx_rsab_exposures_experiment_variant_first"

    add_foreign_key :recording_studio_ab_tests_exposures, :recording_studio_ab_tests_experiments,
                    column: :experiment_id
    add_foreign_key :recording_studio_ab_tests_exposures, :recording_studio_ab_tests_variants,
                    column: :variant_id
    add_foreign_key :recording_studio_ab_tests_exposures, :recording_studio_ab_tests_assignments,
                    column: :assignment_id
  end
end
