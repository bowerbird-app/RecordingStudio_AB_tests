# frozen_string_literal: true

require "test_helper"

class AbOverrideDriftTest < ActiveSupport::TestCase
  include RecordingStudioAbTests::TestHelpers

  setup do
    RecordingStudioAbTests::EventSubscriptions.install!
    @original = RecordingStudioAbTests.registry.target(:signup_page)&.source_template&.dup
  end

  teardown do
    next unless @original

    RecordingStudioAbTests.register_target :signup_page,
      type: :partial,
      label: "Sign-up page body",
      partial: "ab/signup/body",
      variants: { b: { rails_variant: :ab_signup_b } },
      source_template: @original
  end

  test "assert_ab_override_current passes for pinned digest" do
    assert_ab_override_current(:signup_page)
    assert true
  end

  test "assert_ab_override_current fails when digest changes" do
    stale = {
      engine: "RecordingStudioUser::Engine",
      path: "recording_studio_user/auth/registrations/new.html.erb",
      digest: "0" * 64
    }
    RecordingStudioAbTests.register_target :signup_page,
      type: :partial,
      label: "Sign-up page body",
      partial: "ab/signup/body",
      variants: { b: { rails_variant: :ab_signup_b } },
      source_template: stale

    error = assert_raises(Minitest::Assertion) do
      assert_ab_override_current(:signup_page)
    end
    assert_match(/stale|digest/i, error.message)
  end

  test "verify_overrides rake task fails on digest mismatch" do
    require "rake"
    Rails.application.load_tasks

    stale = {
      engine: "RecordingStudioUser::Engine",
      path: "recording_studio_user/auth/registrations/new.html.erb",
      digest: "deadbeef" * 8
    }
    RecordingStudioAbTests.register_target :signup_page,
      type: :partial,
      label: "Sign-up page body",
      partial: "ab/signup/body",
      variants: { b: { rails_variant: :ab_signup_b } },
      source_template: stale

    task = Rake::Task["recording_studio_ab_tests:verify_overrides"]
    task.reenable
    output = capture_io do
      assert_raises(SystemExit) { task.invoke }
    end
    combined = output.join
    assert_match(/FAILED|digest mismatch/i, combined)
  end
end

