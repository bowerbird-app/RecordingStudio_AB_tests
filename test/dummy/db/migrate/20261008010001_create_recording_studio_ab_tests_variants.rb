# frozen_string_literal: true

class CreateRecordingStudioAbTestsVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_ab_tests_variants, id: :uuid do |t|
      t.uuid :experiment_id, null: false
      t.string :key, null: false
      t.string :name, null: false
      t.string :implementation_key, null: false
      t.boolean :is_control, null: false, default: false
      t.integer :weight, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :recording_studio_ab_tests_variants, %i[experiment_id key], unique: true,
                                                                          name: "idx_rsab_variants_experiment_key"
    add_index :recording_studio_ab_tests_variants, %i[experiment_id implementation_key], unique: true,
                                                                                         name: "idx_rsab_variants_experiment_impl"
    add_index :recording_studio_ab_tests_variants, :experiment_id, unique: true,
                                                                   where: "is_control = TRUE",
                                                                   name: "idx_rsab_variants_control"

    add_check_constraint :recording_studio_ab_tests_variants,
                         "weight >= 0",
                         name: "chk_rsab_variants_weight"

    add_foreign_key :recording_studio_ab_tests_variants, :recording_studio_ab_tests_experiments,
                    column: :experiment_id, on_delete: :cascade
  end
end
