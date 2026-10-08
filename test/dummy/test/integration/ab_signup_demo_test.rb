# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbSignupDemoTest < ActionDispatch::IntegrationTest
  include AbTestsHelper

  setup do
    RecordingStudioAbTests::Conversion.delete_all
    RecordingStudioAbTests::Exposure.delete_all
    RecordingStudioAbTests::Assignment.delete_all
    RecordingStudioAbTests::Goal.delete_all
    RecordingStudioAbTests::Variant.delete_all
    RecordingStudioAbTests::Experiment.delete_all
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
    RecordingStudioAbTests::EventSubscriptions.install!

    @experiment = RecordingStudioAbTests::Experiment.create!(
      key: "signup_demo_#{SecureRandom.hex(3)}",
      name: "Signup demo",
      target_key: "signup_page",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "ffff0000eeee1111",
      allocation_version: "sha256-v1",
      status: "draft"
    )
    @experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                 is_control: true, weight: 1, position: 0)
    @experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                 is_control: false, weight: 99, position: 1)
    @experiment.goals.create!(key: "registered", name: "Registered", event_key: "user_registered",
                              is_primary: true)
    @experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
  end

  test "host signup demo renders AB variant via render_ab" do
    get demo_signup_path, headers: BROWSER_UA
    assert_response :success
    assert_select "#signup-variant"
    assert_equal 1, RecordingStudioAbTests::Assignment.count
    assert_equal 1, RecordingStudioAbTests::Exposure.count
  end

  test "override file exists at the gem view path for §14" do
    override = Rails.root.join("app/views/recording_studio_user/auth/registrations/new.html.erb")
    assert File.exist?(override), "expected host override at #{override}"
    assert_match(/render_ab :signup_page/, File.read(override))
  end

  test "registration completed links visitor and converts in request" do
    get demo_signup_path, headers: BROWSER_UA
    assert_response :success
    assignment = RecordingStudioAbTests::Assignment.first
    assert_not_nil assignment
    assert_equal "visitor", assignment.subject_type
    visitor_id = assignment.subject_identifier

    email = "new-signup-#{SecureRandom.hex(4)}@example.com"
    user = User.create!(email: email, password: "Password", password_confirmation: "Password")

    request = ActionDispatch::TestRequest.create
    request.cookie_jar.signed[:_rsab_vid] = visitor_id
    RecordingStudioAbTests::Current.request = request

    ActiveRecord::Base.transaction do
      ActiveSupport::Notifications.instrument(
        RecordingStudioUser::RegistrationCompleted::EVENT,
        user_id: user.id,
        method: :password
      )
    end

    assignment.reload
    assert_equal user.id.to_s, assignment.linked_user_id
    assert_equal "registration.completed", assignment.link_source

    conversion = RecordingStudioAbTests::Conversion.find_by(source_event_key: "user_registered")
    assert_not_nil conversion
    assert_equal assignment.variant_id, conversion.variant_id
    assert_match(/\A[a-f0-9]{64}\z/, conversion.idempotency_key)
  end

  test "Users registrations#new prepends gem views (documented conflict)" do
    get new_user_registration_path, headers: BROWSER_UA
    assert_response :success
    # Gem template wins today — no #signup-variant from the host override.
    assert_select "#signup-variant", count: 0
    assert_match(/Continue with email|Sign up/i, response.body)
  end
end
