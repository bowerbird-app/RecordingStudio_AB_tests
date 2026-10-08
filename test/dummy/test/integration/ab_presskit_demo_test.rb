# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbPresskitDemoTest < ActionDispatch::IntegrationTest
  include AbTestsHelper
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |u|
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
    RecordingStudioAbTests.register_event :presskit_created,
      label: "Press kit created", subject: :user, source: :host

    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "presskit_demo_#{SecureRandom.hex(3)}",
      name: "Presskit",
      target_key: "presskit_cta",
      assignment_scope: "user",
      traffic_percentage: 100,
      allocation_seed: "abcd1234efgh5678",
      allocation_version: "sha256-v1",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                is_control: true, weight: 50, position: 0)
    experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                is_control: false, weight: 50, position: 1)
    experiment.goals.create!(key: "presskit", name: "Press kit", event_key: "presskit_created",
                             is_primary: true, counting_policy: "every_event")
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!

    sign_in @user
  end

  test "presskit page exposes and track_event converts" do
    get demo_presskit_path, headers: BROWSER_UA
    assert_response :success
    assert_select "#presskit-cta"
    assert_equal 1, RecordingStudioAbTests::Assignment.count
    assert_equal 1, RecordingStudioAbTests::Exposure.count

    post demo_presskit_path, headers: BROWSER_UA
    assert_response :redirect
    follow_redirect!
    assert_equal 1, RecordingStudioAbTests::Conversion.where(source_event_key: "presskit_created").count
    assert_select "#presskit-event"
  end
end
