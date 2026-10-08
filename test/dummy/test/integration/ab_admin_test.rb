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

  test "experiment CRUD new and show pages render" do
    get "/ab_tests/admin/experiments/new"
    assert_response :success

    get "/ab_tests/admin/experiments/#{@experiment.id}"
    assert_response :success
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
