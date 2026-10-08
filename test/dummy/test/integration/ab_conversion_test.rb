# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbConversionTest < ActionDispatch::IntegrationTest
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
    RecordingStudioAbTests::EventSubscriptions.install!
  end

  test "track_event converts only after commit" do
    experiment = create_user_scoped_experiment!(event_key: "presskit_created")
    assignment = create_user_assignment!(experiment, @user)

    assert_no_difference -> { RecordingStudioAbTests::Conversion.count } do
      ActiveRecord::Base.transaction do
        RecordingStudioAbTests.track_event(
          :presskit_created,
          subject: @user,
          event_id: "pk-rollback",
          occurred_at: Time.current
        )
        raise ActiveRecord::Rollback
      end
    end

    assert_difference -> { RecordingStudioAbTests::Conversion.count }, 1 do
      RecordingStudioAbTests.track_event(
        :presskit_created,
        subject: @user,
        event_id: "pk-commit",
        occurred_at: Time.current
      )
    end

    conversion = RecordingStudioAbTests::Conversion.last
    assert_equal assignment.id, conversion.assignment_id
    assert_equal assignment.variant_id, conversion.variant_id
    assert_equal "presskit_created", conversion.source_event_key
  end

  test "duplicate delivery yields one conversion row" do
    experiment = create_user_scoped_experiment!(event_key: "presskit_created", counting: "once_per_participant")
    create_user_assignment!(experiment, @user)

    2.times do
      RecordingStudioAbTests.track_event(:presskit_created, subject: @user, event_id: "dup-1")
    end
    assert_equal 1, RecordingStudioAbTests::Conversion.count
  end

  test "password oauth and otp registration payloads convert" do
    experiment = create_visitor_signup_experiment!
    visitor_id = SecureRandom.uuid
    create_visitor_assignment!(experiment, visitor_id)

    %i[password oauth otp].each_with_index do |method, index|
      user = User.create!(
        email: "reg-#{method}-#{index}@example.com",
        password: "Password",
        password_confirmation: "Password"
      )
      RecordingStudioAbTests::Current.reset
      request = ActionDispatch::TestRequest.create
      request.cookie_jar.signed[:_rsab_vid] = visitor_id
      RecordingStudioAbTests::Current.request = request

      ActiveRecord::Base.transaction do
        ActiveSupport::Notifications.instrument(
          "registration.completed.recording_studio_user",
          user_id: user.id,
          method: method
        )
      end
    end

    assert_operator RecordingStudioAbTests::Conversion.where(source_event_key: "user_registered").count, :>=, 1
  end

  test "unknown event raises in test" do
    assert_raises(RecordingStudioAbTests::UnknownEvent) do
      RecordingStudioAbTests.track_event(:not_a_real_event, subject: @user)
    end
  end

  test "no retrospective assignment on conversion" do
    create_user_scoped_experiment!(event_key: "presskit_created")
    assert_no_difference -> { RecordingStudioAbTests::Assignment.count } do
      RecordingStudioAbTests.track_event(:presskit_created, subject: @user, event_id: "none")
    end
    assert_equal 0, RecordingStudioAbTests::Conversion.count
  end

  test "every_event without event_id raises" do
    experiment = create_user_scoped_experiment!(event_key: "presskit_created", counting: "every_event")
    create_user_assignment!(experiment, @user)

    assert_raises(RecordingStudioAbTests::InvalidEvent) do
      RecordingStudioAbTests.track_event(:presskit_created, subject: @user, event_id: nil)
    end
  end

  private

  def create_user_scoped_experiment!(event_key:, counting: "once_per_participant")
    RecordingStudioAbTests.register_event event_key.to_sym, label: event_key.to_s, subject: :user, source: :host
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "conv_#{SecureRandom.hex(4)}",
      name: "Conversion",
      target_key: "pricing_page",
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
    experiment.goals.create!(key: "primary", name: "Primary", event_key: event_key.to_s,
                             is_primary: true, counting_policy: counting)
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
    experiment
  end

  def create_visitor_signup_experiment!
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "signup_#{SecureRandom.hex(4)}",
      name: "Signup",
      target_key: "signup_page",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "abcd1234efgh5678",
      allocation_version: "sha256-v1",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                is_control: true, weight: 1, position: 0)
    experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                is_control: false, weight: 99, position: 1)
    experiment.goals.create!(key: "registered", name: "Registered", event_key: "user_registered",
                             is_primary: true)
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
    experiment
  end

  def create_user_assignment!(experiment, user)
    RecordingStudioAbTests::Assignment.create!(
      experiment: experiment,
      variant: experiment.variants.find_by!(key: "b"),
      subject_type: "user",
      subject_identifier: user.id.to_s,
      allocation_version: experiment.allocation_version,
      bucket: 1,
      assigned_at: 1.hour.ago
    )
  end

  def create_visitor_assignment!(experiment, visitor_id)
    RecordingStudioAbTests::Assignment.create!(
      experiment: experiment,
      variant: experiment.variants.find_by!(key: "b"),
      subject_type: "visitor",
      subject_identifier: visitor_id,
      allocation_version: experiment.allocation_version,
      bucket: 1,
      assigned_at: 1.hour.ago
    )
  end
end
