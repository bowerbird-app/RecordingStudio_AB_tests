# frozen_string_literal: true

require "test_helper"

class AbHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_ALERT_TITLE = "HOST Could not save"
  HOST_PRIMARY_EVENT_FROZEN = "HOST primary goal event is frozen after start"
  HOST_FROZEN_AFTER_START = "HOST cannot change after experiment has started"
  OVERRIDE_KEY = "recording_studio.ab_tests.experiments.new.alert_title"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_ab_tests_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/ab_tests_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @user = User.find_or_create_by!(email: "admin@admin.com") do |u|
      u.password = "Password"
      u.password_confirmation = "Password"
    end
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    Current.actor = @user
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: @admin_recording,
      actor: @user
    )
    raise result.error if result.failure?

    sign_in @user
    switch_to_admin_root!
  end

  teardown do
    Current.actor = nil
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  def switch_to_admin_root!
    get "/recording_studio_root_switchable/v1/root_switch", params: { scope: "all_workspaces" }
    assert_response :success

    patch "/recording_studio_root_switchable/v1/root_switch",
          params: {
            scope: "all_workspaces",
            root_switch: {
              root_recording_id: @admin_recording.id,
              scope: "all_workspaces"
            }
          }
    assert_response :redirect
    follow_redirect!
  end

  # Real-boot-order guard from #10 / v0.4.1: host file under config/locales must win
  # without any test-time load_path mutation.
  test "host locale override for recording_studio.ab_tests wins on real admin page" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_ALERT_TITLE
    assert_equal HOST_ALERT_TITLE, I18n.t(OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    post "/ab_tests/admin/experiments",
         params: {
           experiment: {
             name: "",
             key: "",
             target_key: "pricing_page",
             assignment_scope: "visitor",
             traffic_percentage: 100,
             primary_event_key: "demo_signup"
           }
         }

    assert_response :unprocessable_entity
    assert_includes response.body, HOST_ALERT_TITLE
    assert_includes response.body, "New experiment"
    refute_includes response.body, "HOST New experiment"
  end

  test "fresh-backend last-file-wins host fixture overrides gem english on admin page" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_ALERT_TITLE

    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = @load_path_before + [FRESH_HOST_LOCALE.to_s]
    I18n.backend.load_translations

    assert_equal HOST_ALERT_TITLE, I18n.t(OVERRIDE_KEY)

    post "/ab_tests/admin/experiments",
         params: {
           experiment: {
             name: "",
             key: "",
             target_key: "pricing_page",
             assignment_scope: "visitor",
             traffic_percentage: 100,
             primary_event_key: "demo_signup"
           }
         }

    assert_response :unprocessable_entity
    assert_includes response.body, HOST_ALERT_TITLE
    assert_includes response.body, "New experiment"
    refute_includes response.body, "HOST New experiment"
  ensure
    I18n.load_path = @load_path_before
    I18n.backend = @backend_before
  end

  test "host locale override for validation error renders on goal update" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_PRIMARY_EVENT_FROZEN
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_FROZEN_AFTER_START

    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = @load_path_before + [FRESH_HOST_LOCALE.to_s]
    I18n.backend.load_translations

    assert_equal HOST_FROZEN_AFTER_START,
                 I18n.t("recording_studio.ab_tests.errors.frozen_after_start")
    assert_equal HOST_PRIMARY_EVENT_FROZEN,
                 I18n.t("recording_studio.ab_tests.errors.primary_event_frozen")

    # Unique target_key: live rows share idx_rsab_experiments_live_target with seeds.
    experiment = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "host_frozen_demo")
    if experiment.new_record?
      experiment.assign_attributes(
        name: "Host frozen demo",
        target_key: "host_frozen_target",
        assignment_scope: "visitor",
        traffic_percentage: 100,
        status: "draft",
        allocation_version: "sha256-v1",
        allocation_seed: SecureRandom.hex(8),
        created_by: @user
      )
      experiment.save!
      experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                  is_control: true, weight: 1, position: 0)
      experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                  is_control: false, weight: 1, position: 1)
      experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup",
                               is_primary: true)
    else
      experiment.update_columns(target_key: "host_frozen_target") unless experiment.target_key == "host_frozen_target"
    end
    experiment.update_columns(status: "running", started_at: Time.current) if experiment.draft?
    primary = experiment.goals.find_by!(is_primary: true)

    refute experiment.update(key: "renamed_host_frozen")
    assert_equal [{ error: HOST_FROZEN_AFTER_START }], experiment.errors.details[:key]
    experiment.reload

    patch "/ab_tests/admin/experiments/#{experiment.id}/goals/#{primary.id}",
          params: {
            goal: {
              name: primary.name,
              event_key: "other_event",
              counting_policy: primary.counting_policy,
              attribution_window_hours: primary.attribution_window_hours
            }
          }

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, HOST_PRIMARY_EVENT_FROZEN
    refute_includes response.body, "Event key primary goal event is frozen after start"
  ensure
    I18n.load_path = @load_path_before
    I18n.backend = @backend_before
  end
end
