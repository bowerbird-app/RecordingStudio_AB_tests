# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbIdentityLinkingTest < ActionDispatch::IntegrationTest
  include AbTestsHelper

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
  end

  test "link_identity sets linked columns on visitor rows" do
    experiment = create_visitor_experiment!
    visitor_id = SecureRandom.uuid
    assignment = create_visitor_assignment!(experiment, visitor_id)

    RecordingStudioAbTests.link_identity(
      visitor_id: visitor_id,
      user: @user,
      source: "host"
    )

    assignment.reload
    assert_equal @user.id.to_s, assignment.linked_user_id
    assert_equal "host", assignment.link_source
    assert_not_nil assignment.linked_at
  end

  test "user row wins over promotion" do
    experiment = create_user_scoped_visitor_experiment!
    visitor_id = SecureRandom.uuid
    visitor_row = create_visitor_assignment!(experiment, visitor_id, variant_key: "b")
    user_row = RecordingStudioAbTests::Assignment.create!(
      experiment: experiment,
      variant: experiment.variants.find_by!(key: "control"),
      subject_type: "user",
      subject_identifier: @user.id.to_s,
      allocation_version: experiment.allocation_version,
      bucket: 2,
      assigned_at: 2.hours.ago
    )

    RecordingStudioAbTests.link_identity(visitor_id: visitor_id, user: @user, source: "host")

    assert_equal 1, RecordingStudioAbTests::Assignment.where(
      experiment_id: experiment.id, subject_type: "user", subject_identifier: @user.id.to_s
    ).count
    assert_equal user_row.variant_id, user_row.reload.variant_id
    assert_equal @user.id.to_s, visitor_row.reload.linked_user_id
  end

  test "promotion creates user row when absent" do
    experiment = create_user_scoped_visitor_experiment!
    visitor_id = SecureRandom.uuid
    visitor_row = create_visitor_assignment!(experiment, visitor_id, variant_key: "b")

    RecordingStudioAbTests.link_identity(visitor_id: visitor_id, user: @user, source: "registration.completed")

    promoted = RecordingStudioAbTests::Assignment.find_by!(
      experiment_id: experiment.id,
      subject_type: "user",
      subject_identifier: @user.id.to_s
    )
    assert_equal visitor_row.variant_id, promoted.variant_id
    assert_equal visitor_row.id, promoted.promoted_from_assignment_id
    assert_equal visitor_row.assigned_at.to_i, promoted.assigned_at.to_i
  end

  test "job context gets no auto-link from registration notification" do
    experiment = create_visitor_experiment!
    visitor_id = SecureRandom.uuid
    create_visitor_assignment!(experiment, visitor_id)
    RecordingStudioAbTests::EventSubscriptions.install!

    RecordingStudioAbTests::Current.reset
    # No Current.request → notification must not auto-link
    ActiveSupport::Notifications.instrument(
      "registration.completed.recording_studio_user",
      user_id: @user.id,
      method: :password
    )

    assert_nil RecordingStudioAbTests::Assignment.find_by(
      subject_type: "visitor", subject_identifier: visitor_id
    ).linked_user_id
  end

  test "explicit visitor_id link_identity works outside request" do
    experiment = create_visitor_experiment!
    visitor_id = SecureRandom.uuid
    create_visitor_assignment!(experiment, visitor_id)
    RecordingStudioAbTests::Current.reset

    RecordingStudioAbTests.link_identity(visitor_id: visitor_id, user: @user, source: "host")
    assert_equal @user.id.to_s, RecordingStudioAbTests::Assignment.find_by!(
      subject_identifier: visitor_id
    ).linked_user_id
  end

  private

  def create_visitor_experiment!
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "link_#{SecureRandom.hex(4)}",
      name: "Link",
      target_key: "pricing_page",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "abcd1234efgh5678",
      allocation_version: "sha256-v1",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                is_control: true, weight: 50, position: 0)
    experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                is_control: false, weight: 50, position: 1)
    experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup", is_primary: true)
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
    experiment
  end

  def create_user_scoped_visitor_experiment!
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "ulink_#{SecureRandom.hex(4)}",
      name: "User link",
      target_key: "hero_component",
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
    experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup", is_primary: true)
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
    experiment
  end

  def create_visitor_assignment!(experiment, visitor_id, variant_key: "b")
    RecordingStudioAbTests::Assignment.create!(
      experiment: experiment,
      variant: experiment.variants.find_by!(key: variant_key),
      subject_type: "visitor",
      subject_identifier: visitor_id,
      allocation_version: experiment.allocation_version,
      bucket: 1,
      assigned_at: 1.hour.ago
    )
  end
end
