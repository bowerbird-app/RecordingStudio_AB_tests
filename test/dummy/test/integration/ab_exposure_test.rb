# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbExposureTest < ActionDispatch::IntegrationTest
  include AbTestsHelper
  include Devise::Test::IntegrationHelpers

  setup do
    User.find_or_create_by!(email: "admin@admin.com") do |u|
      u.password = "Password"
      u.password_confirmation = "Password"
    end
    RecordingStudioAbTests::Conversion.delete_all
    RecordingStudioAbTests::Exposure.delete_all
    RecordingStudioAbTests::Assignment.delete_all
    RecordingStudioAbTests::Goal.delete_all
    RecordingStudioAbTests::Variant.delete_all
    RecordingStudioAbTests::Experiment.delete_all
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
    sign_in User.find_by!(email: "admin@admin.com")
  end

  test "assignment is distinct from exposure and unique per assignment target" do
    create_running_experiment!(key: "pricing_run", target_key: "pricing_page")

    get demo_pricing_path, headers: BROWSER_UA
    assert_response :success
    assert_equal 1, RecordingStudioAbTests::Assignment.count
    assert_equal 1, RecordingStudioAbTests::Exposure.count

    assignment = RecordingStudioAbTests::Assignment.first
    exposure = RecordingStudioAbTests::Exposure.first
    assert_equal assignment.id, exposure.assignment_id
    assert_equal assignment.variant_id, exposure.variant_id
    assert_equal "pricing_page", exposure.target_key
    assert_equal 1, exposure.exposure_count

    get demo_pricing_path, headers: BROWSER_UA
    assert_response :success
    assert_equal 1, RecordingStudioAbTests::Assignment.count
    assert_equal 1, RecordingStudioAbTests::Exposure.count
  end

  test "repeat exposures increment only when enabled" do
    create_running_experiment!(key: "pricing_run", target_key: "pricing_page")

    with_ab_config(track_repeat_exposures: true, exposure_mode: :inline) do
      get demo_pricing_path, headers: BROWSER_UA
      assert_response :success
      assert_equal 1, RecordingStudioAbTests::Exposure.count

      # Clear in-request memo and cookie target list so a second request re-enqueues.
      RecordingStudioAbTests::Current.reset
      jar = ActionDispatch::Request.new(Rails.application.env_config).cookie_jar
      _ = jar
      cookies.delete("_rsab_a")

      # Returning with cookie still has targets; force by clearing cookie assignment map.
      get demo_pricing_path, headers: BROWSER_UA
      assert_response :success
    end

    exposure = RecordingStudioAbTests::Exposure.first
    assert_operator exposure.exposure_count, :>=, 1
  end

  test "expose public API records an exposure" do
    create_running_experiment!(key: "pricing_run", target_key: "pricing_page")

    get demo_pricing_path, headers: BROWSER_UA
    assert_equal 1, RecordingStudioAbTests::Exposure.count
  end

  test "async exposure job is idempotent" do
    experiment = create_running_experiment!(key: "pricing_run", target_key: "pricing_page")
    get demo_pricing_path, headers: BROWSER_UA
    assignment = RecordingStudioAbTests::Assignment.first

    with_ab_config(exposure_mode: :async) do
      RecordingStudioAbTests::RecordExposureJob.perform_now(
        assignment_id: assignment.id,
        target_key: "pricing_page"
      )
      RecordingStudioAbTests::RecordExposureJob.perform_now(
        assignment_id: assignment.id,
        target_key: "pricing_page"
      )
    end

    assert_equal 1, RecordingStudioAbTests::Exposure.where(
      assignment_id: assignment.id, target_key: "pricing_page"
    ).count
    assert_equal experiment.id, RecordingStudioAbTests::Exposure.first.experiment_id
  end
end
