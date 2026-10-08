# frozen_string_literal: true

class CreateRecordingStudioAbTestsAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_assignments, id: :uuid do |t|
      t.uuid :experiment_id, null: false
      t.uuid :variant_id, null: false
      t.string :subject_type, null: false
      t.string :subject_identifier, null: false
      t.uuid :root_recording_id
      t.string :allocation_version, null: false
      t.integer :bucket, null: false
      t.datetime :assigned_at, null: false
      t.string :linked_user_id
      t.datetime :linked_at
      t.string :link_source
      t.uuid :promoted_from_assignment_id

      t.timestamps
    end

    add_index :recording_studio_ab_tests_assignments,
              %i[experiment_id subject_type subject_identifier],
              unique: true,
              name: "idx_rsab_assignments_subject"
    add_index :recording_studio_ab_tests_assignments, %i[experiment_id variant_id],
              name: "idx_rsab_assignments_experiment_variant"
    add_index :recording_studio_ab_tests_assignments, :linked_user_id,
              where: "linked_user_id IS NOT NULL",
              name: "idx_rsab_assignments_linked_user"
    add_index :recording_studio_ab_tests_assignments, %i[experiment_id assigned_at],
              name: "idx_rsab_assignments_experiment_assigned"

    add_check_constraint :recording_studio_ab_tests_assignments,
                         "subject_type IN ('visitor', 'user', 'root_recording')",
                         name: "chk_rsab_assignments_subject_type"
    add_check_constraint :recording_studio_ab_tests_assignments,
                         "bucket >= 0 AND bucket <= 9999",
                         name: "chk_rsab_assignments_bucket"

    add_foreign_key :recording_studio_ab_tests_assignments, :recording_studio_ab_tests_experiments,
                    column: :experiment_id
    add_foreign_key :recording_studio_ab_tests_assignments, :recording_studio_ab_tests_variants,
                    column: :variant_id
  end
end
