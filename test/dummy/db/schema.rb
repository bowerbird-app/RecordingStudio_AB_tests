# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_010005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "folders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "recording_studio_ab_tests_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.uuid "variant_id", null: false
    t.string "subject_type", null: false
    t.string "subject_identifier", null: false
    t.uuid "root_recording_id"
    t.string "allocation_version", null: false
    t.integer "bucket", null: false
    t.datetime "assigned_at", null: false
    t.string "linked_user_id"
    t.datetime "linked_at"
    t.string "link_source"
    t.uuid "promoted_from_assignment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["experiment_id", "assigned_at"], name: "idx_rsab_assignments_experiment_assigned"
    t.index ["experiment_id", "subject_type", "subject_identifier"], name: "idx_rsab_assignments_subject", unique: true
    t.index ["experiment_id", "variant_id"], name: "idx_rsab_assignments_experiment_variant"
    t.index ["linked_user_id"], name: "idx_rsab_assignments_linked_user", where: "(linked_user_id IS NOT NULL)"
    t.check_constraint "bucket >= 0 AND bucket <= 9999", name: "chk_rsab_assignments_bucket"
    t.check_constraint "subject_type::text = ANY (ARRAY['visitor'::character varying, 'user'::character varying, 'root_recording'::character varying]::text[])", name: "chk_rsab_assignments_subject_type"
  end

  create_table "recording_studio_ab_tests_conversions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.uuid "variant_id", null: false
    t.uuid "assignment_id", null: false
    t.uuid "goal_id", null: false
    t.string "source_event_key", null: false
    t.string "source_event_id"
    t.string "idempotency_key", null: false
    t.datetime "occurred_at", null: false
    t.decimal "value", precision: 18, scale: 4
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["assignment_id", "goal_id"], name: "idx_rsab_conversions_assignment_goal"
    t.index ["experiment_id", "goal_id", "variant_id"], name: "idx_rsab_conversions_experiment_goal_variant"
    t.index ["idempotency_key"], name: "idx_rsab_conversions_idem", unique: true
  end

  create_table "recording_studio_ab_tests_experiments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "target_key", null: false
    t.string "assignment_scope", null: false
    t.integer "traffic_percentage", default: 100, null: false
    t.string "allocation_seed", null: false
    t.string "allocation_version", default: "sha256-v1", null: false
    t.uuid "scope_root_recording_id"
    t.uuid "winner_variant_id"
    t.datetime "started_at"
    t.datetime "paused_at"
    t.datetime "completed_at"
    t.datetime "archived_at"
    t.string "created_by_type"
    t.uuid "created_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "idx_rsab_experiments_key", unique: true
    t.index ["target_key", "status"], name: "idx_rsab_experiments_target_status"
    t.index ["target_key"], name: "idx_rsab_experiments_live_target", unique: true, where: "((status)::text = ANY ((ARRAY['running'::character varying, 'paused'::character varying])::text[]))"
    t.check_constraint "assignment_scope::text = ANY (ARRAY['visitor'::character varying, 'user'::character varying, 'root_recording'::character varying]::text[])", name: "chk_rsab_experiments_scope"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'running'::character varying, 'paused'::character varying, 'completed'::character varying, 'archived'::character varying]::text[])", name: "chk_rsab_experiments_status"
    t.check_constraint "traffic_percentage >= 0 AND traffic_percentage <= 100", name: "chk_rsab_experiments_traffic"
  end

  create_table "recording_studio_ab_tests_exposures", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.uuid "variant_id", null: false
    t.uuid "assignment_id", null: false
    t.string "target_key", null: false
    t.datetime "first_exposed_at", null: false
    t.datetime "last_exposed_at", null: false
    t.integer "exposure_count", default: 1, null: false
    t.string "request_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id", "target_key"], name: "idx_rsab_exposures_unique", unique: true
    t.index ["experiment_id", "variant_id", "first_exposed_at"], name: "idx_rsab_exposures_experiment_variant_first"
  end

  create_table "recording_studio_ab_tests_goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "event_key", null: false
    t.boolean "is_primary", default: false, null: false
    t.integer "attribution_window_hours", default: 168, null: false
    t.string "counting_policy", default: "once_per_participant", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_key"], name: "idx_rsab_goals_event_key"
    t.index ["experiment_id", "key"], name: "idx_rsab_goals_experiment_key", unique: true
    t.index ["experiment_id"], name: "idx_rsab_goals_primary", unique: true, where: "(is_primary = true)"
    t.check_constraint "attribution_window_hours >= 1 AND attribution_window_hours <= 2160", name: "chk_rsab_goals_window"
    t.check_constraint "counting_policy::text = ANY (ARRAY['once_per_participant'::character varying, 'every_event'::character varying]::text[])", name: "chk_rsab_goals_counting"
  end

  create_table "recording_studio_ab_tests_variants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "experiment_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "implementation_key", null: false
    t.boolean "is_control", default: false, null: false
    t.integer "weight", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["experiment_id", "implementation_key"], name: "idx_rsab_variants_experiment_impl", unique: true
    t.index ["experiment_id", "key"], name: "idx_rsab_variants_experiment_key", unique: true
    t.index ["experiment_id"], name: "idx_rsab_variants_control", unique: true, where: "(is_control = true)"
    t.check_constraint "weight >= 0", name: "chk_rsab_variants_weight"
  end

  create_table "recording_studio_access_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "recording_id", null: false
    t.string "email", null: false
    t.string "role", null: false
    t.string "token_digest", limit: 64, null: false
    t.string "manager_actor_type", null: false
    t.uuid "manager_actor_id", null: false
    t.string "accepted_by_actor_type"
    t.uuid "accepted_by_actor_id"
    t.datetime "expires_at", null: false
    t.datetime "last_sent_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id", "email"], name: "idx_rs_access_invitations_one_active", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["recording_id"], name: "index_recording_studio_access_invitations_on_recording_id"
    t.index ["token_digest"], name: "idx_rs_access_invitations_token_digest", unique: true
    t.check_constraint "accepted_at IS NULL OR revoked_at IS NULL", name: "access_invitations_not_accepted_and_revoked"
  end

  create_table "recording_studio_accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.uuid "depends_on_recording_id"
    t.integer "role", default: 0, null: false
    t.index ["actor_type", "actor_id", "role"], name: "index_recording_studio_accesses_on_actor_and_role"
    t.index ["actor_type", "actor_id"], name: "index_recording_studio_accesses_on_actor"
    t.index ["depends_on_recording_id"], name: "index_recording_studio_accesses_on_depends_on_recording_id"
  end

  create_table "recording_studio_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.uuid "impersonator_id"
    t.string "impersonator_type"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "previous_recordable_id"
    t.string "previous_recordable_type"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "recording_id", null: false
    t.index ["action", "occurred_at"], name: "index_rs_events_on_action_and_occurred_at"
    t.index ["actor_type", "actor_id", "occurred_at"], name: "index_rs_events_on_actor_and_occurred_at"
    t.index ["recording_id", "idempotency_key"], name: "index_recording_studio_events_on_recording_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["recording_id", "occurred_at", "created_at"], name: "index_rs_events_on_recording_and_timeline", order: { occurred_at: :desc, created_at: :desc }
    t.index ["recording_id"], name: "index_recording_studio_events_on_recording_id"
  end

  create_table "recording_studio_recordings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "parent_recording_id"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "root_recording_id"
    t.datetime "trashed_at"
    t.datetime "updated_at", null: false
    t.index ["parent_recording_id"], name: "index_recording_studio_recordings_on_parent_recording_id"
    t.index ["recordable_type", "recordable_id", "parent_recording_id", "trashed_at"], name: "index_recording_studio_recordings_on_recordable_parent_trashed"
    t.index ["recordable_type", "recordable_id"], name: "index_recording_studio_recordings_on_recordable"
    t.index ["recordable_type", "recordable_id"], name: "index_rs_unique_root_recording_per_recordable", unique: true, where: "(parent_recording_id IS NULL)"
    t.index ["root_recording_id", "parent_recording_id"], name: "index_rs_recordings_on_root_and_parent"
    t.index ["root_recording_id", "recordable_type", "recordable_id"], name: "index_rs_recordings_on_root_and_recordable"
    t.index ["root_recording_id"], name: "index_rs_recordings_on_root_recording"
  end

  create_table "recording_studio_root_switchable_selections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "device_browser"
    t.string "device_key", null: false
    t.string "device_label"
    t.string "device_platform"
    t.string "device_type"
    t.datetime "last_used_at", null: false
    t.uuid "root_recording_id", null: false
    t.string "scope_key", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["actor_type", "actor_id", "device_key", "scope_key"], name: "idx_rs_root_switchable_actor_device_scope", unique: true, where: "(actor_id IS NOT NULL)"
    t.index ["device_key", "scope_key"], name: "idx_rs_root_switchable_anonymous_device_scope", unique: true, where: "(actor_id IS NULL)"
    t.index ["root_recording_id"], name: "idx_rs_root_switchable_root_recording"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "recording_studio_ab_tests_assignments", "recording_studio_ab_tests_experiments", column: "experiment_id"
  add_foreign_key "recording_studio_ab_tests_assignments", "recording_studio_ab_tests_variants", column: "variant_id"
  add_foreign_key "recording_studio_ab_tests_conversions", "recording_studio_ab_tests_assignments", column: "assignment_id"
  add_foreign_key "recording_studio_ab_tests_conversions", "recording_studio_ab_tests_experiments", column: "experiment_id"
  add_foreign_key "recording_studio_ab_tests_conversions", "recording_studio_ab_tests_goals", column: "goal_id"
  add_foreign_key "recording_studio_ab_tests_conversions", "recording_studio_ab_tests_variants", column: "variant_id"
  add_foreign_key "recording_studio_ab_tests_experiments", "recording_studio_recordings", column: "scope_root_recording_id", validate: false
  add_foreign_key "recording_studio_ab_tests_exposures", "recording_studio_ab_tests_assignments", column: "assignment_id"
  add_foreign_key "recording_studio_ab_tests_exposures", "recording_studio_ab_tests_experiments", column: "experiment_id"
  add_foreign_key "recording_studio_ab_tests_exposures", "recording_studio_ab_tests_variants", column: "variant_id"
  add_foreign_key "recording_studio_ab_tests_goals", "recording_studio_ab_tests_experiments", column: "experiment_id", on_delete: :cascade
  add_foreign_key "recording_studio_ab_tests_variants", "recording_studio_ab_tests_experiments", column: "experiment_id", on_delete: :cascade
  add_foreign_key "recording_studio_access_invitations", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_events", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "parent_recording_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "root_recording_id"
end
