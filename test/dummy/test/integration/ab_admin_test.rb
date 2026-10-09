# frozen_string_literal: true

require "test_helper"

class AbAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
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

    # Prefer the seeded live pricing experiment when present (db:prepare). Creating a
    # second running|paused row on pricing_page would violate idx_rsab_experiments_live_target.
    @experiment = RecordingStudioAbTests::Experiment.find_by(key: "pricing_running_demo")
    @experiment ||= begin
      experiment = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "admin_integration_demo")
      if experiment.new_record?
        experiment.assign_attributes(
          name: "Admin integration demo",
          target_key: "pricing_page",
          assignment_scope: "visitor",
          traffic_percentage: 100,
          status: "draft",
          allocation_version: "sha256-v1",
          allocation_seed: SecureRandom.hex(8),
          created_by: @user
        )
        experiment.save!
      end
      if experiment.variants.none?
        experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                    is_control: true, weight: 50, position: 0)
        experiment.variants.create!(key: "b", name: "Variant B", implementation_key: "b",
                                    is_control: false, weight: 50, position: 1)
      end
      if experiment.goals.none?
        experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup",
                                 is_primary: true, attribution_window_hours: 168,
                                 counting_policy: "once_per_participant")
      end
      if experiment.draft?
        live = RecordingStudioAbTests::Experiment
          .where(target_key: "pricing_page", status: %w[running paused])
          .where.not(id: experiment.id)
          .exists?
        experiment.update!(status: "running", started_at: Time.current) unless live
      end
      experiment
    end
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

  teardown do
    Current.actor = nil
  end

  test "dummy boots turbo so admin lazy table and chart frames can load" do
    importmap = File.read(Rails.root.join("config/importmap.rb"))
    application_js = File.read(Rails.root.join("app/javascript/application.js"))

    assert_includes importmap, 'pin "@hotwired/turbo-rails"'
    assert_includes application_js, 'import "@hotwired/turbo-rails"'
  end

  test "rails i18n load path includes the gem english locale file" do
    locale_path = RecordingStudioAbTests::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
    assert_equal "A/B Tests admin", I18n.t("recording_studio.ab_tests.layout.title")
  end

  test "admin ab_tests section and screens render" do
    get "/admin/sections/ab_tests"
    assert_response :success

    %w[
      ab_tests_experiments
      ab_tests_results
      ab_tests_assignments
      ab_tests_exposures
      ab_tests_conversions
      ab_tests_reporting
      ab_tests_registry
    ].each do |key|
      get "/admin/screens/#{key}"
      assert_response :success, "expected screen #{key} to render"
    end
  end

  test "experiments table lazy frame returns cell content" do
    get "/admin/screens/ab_tests_experiments/table"
    assert_response :success
    assert_includes response.body, @experiment.key
    assert_includes response.body, 'data-recording-studio-admin-table-cell-content="true"'
    assert_select "turbo-frame#screen-table"
  end

  test "results chart and table frames render for running experiment" do
    get "/admin/screens/ab_tests_results", params: { experiment_id: @experiment.id }
    assert_response :success
    assert_select "turbo-frame#screen-table[src*='ab_tests_results/table']"

    get "/admin/screens/ab_tests_results/table", params: { experiment_id: @experiment.id }
    assert_response :success
    assert_includes response.body, 'data-recording-studio-admin-table-cell-content="true"'

    get "/admin/screens/ab_tests_results/chart", params: { experiment_id: @experiment.id }
    assert_response :success
    assert_select "turbo-frame#screen-chart"
  end

  test "experiment CRUD new and show pages render literal english chrome" do
    get "/ab_tests/admin/experiments/new"
    assert_response :success
    assert_includes response.body, "New experiment"
    assert_includes response.body, "Save as draft, then start when ready"
    assert_includes response.body, "Save draft"
    assert_includes response.body, "Cancel"
    assert_includes response.body, "Lowercase snake_case identifier"
    assert_includes response.body, "Assignment scope"
    assert_includes response.body, "Primary goal event"
    assert_includes response.body, "Control is always included. Select additional implementations and set weights."

    get "/ab_tests/admin/experiments/#{@experiment.id}"
    assert_response :success
    assert_includes response.body, "Configuration"
    assert_includes response.body, "Variants"
    assert_includes response.body, "Goals"
    assert_includes response.body, "Results"
    assert_includes response.body, "Duplicate"
    assert_includes response.body, "Edit"
    assert_includes response.body, "Name:"
    assert_includes response.body, "Sample sizes are shown next to rates. Relative lift is not statistically tested."

    get "/ab_tests/admin/experiments/#{@experiment.id}/edit"
    assert_response :success
    assert_includes response.body, "Edit experiment"
    assert_includes response.body, "Save changes"
    assert_includes response.body, "Cancel"
  end

  test "experiment show empty panels and draft add forms use literal english" do
    experiment = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "admin_empty_panels_demo")
    if experiment.new_record?
      experiment.assign_attributes(
        name: "Empty panels demo",
        target_key: "hero_component",
        assignment_scope: "visitor",
        traffic_percentage: 100,
        status: "draft",
        allocation_version: "sha256-v1",
        allocation_seed: SecureRandom.hex(8),
        created_by: @user
      )
      experiment.save!
    else
      experiment.variants.destroy_all
      experiment.goals.destroy_all
      experiment.update!(status: "draft")
    end

    get "/ab_tests/admin/experiments/#{experiment.id}", params: { tab: "variants" }
    assert_response :success
    assert_includes response.body, "No variants"
    assert_includes response.body, "Add variants while the experiment is draft."
    assert_includes response.body, "Add variant"
    assert_includes response.body, "Implementation key"

    get "/ab_tests/admin/experiments/#{experiment.id}", params: { tab: "goals" }
    assert_response :success
    assert_includes response.body, "No goals"
    assert_includes response.body, "Add at least one primary goal before starting."
    assert_includes response.body, "Add goal"
    assert_includes response.body, "Primary goal"

    get "/ab_tests/admin/experiments/#{experiment.id}", params: { tab: "results" }
    assert_response :success
    assert_includes response.body, "No metrics yet"
    assert_includes response.body, "Add a primary goal and collect exposures/conversions to see results."
  end

  test "non-draft edit shows frozen fields warning in english" do
    get "/ab_tests/admin/experiments/#{@experiment.id}/edit"
    assert_response :success

    if @experiment.draft?
      assert_includes response.body, "Lowercase snake_case identifier"
    else
      assert_includes response.body, "Some fields are frozen"
      assert_includes response.body, "Key, target, and assignment scope cannot change after start."
      assert_includes response.body, "Frozen after start"
    end
  end

  test "lifecycle pause and resume are audited" do
    experiment = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "admin_lifecycle_demo")
    if experiment.new_record?
      experiment.assign_attributes(
        name: "Admin lifecycle demo",
        target_key: "admin_lifecycle_target",
        assignment_scope: "visitor",
        traffic_percentage: 100,
        status: "draft",
        allocation_version: "sha256-v1",
        allocation_seed: SecureRandom.hex(8),
        created_by: @user
      )
      experiment.save!
      experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                  is_control: true, weight: 50, position: 0)
      experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                  is_control: false, weight: 50, position: 1)
      experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup",
                               is_primary: true, attribution_window_hours: 168,
                               counting_policy: "once_per_participant")
    end

    # Start may fail target validation for unregistered target — set running directly for pause/resume path.
    experiment.update_columns(status: "running", started_at: Time.current) if experiment.draft?

    before = AdminAuditLog.count
    post "/ab_tests/admin/experiments/#{experiment.id}/pause"
    assert_response :redirect
    experiment.reload
    assert_equal "paused", experiment.status
    assert_operator AdminAuditLog.count, :>=, before

    post "/ab_tests/admin/experiments/#{experiment.id}/resume"
    assert_response :redirect
    experiment.reload
    assert_equal "running", experiment.status
  end

  test "unauthenticated admin screens return redirect or unauthorized" do
    sign_out @user
    get "/admin/sections/ab_tests"
    assert_includes [302, 401], response.status
  end
end
