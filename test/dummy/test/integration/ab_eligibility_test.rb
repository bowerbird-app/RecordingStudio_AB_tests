# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbEligibilityTest < ActionDispatch::IntegrationTest
  include AbTestsHelper
  include Devise::Test::IntegrationHelpers

  setup do
    User.find_or_create_by!(email: "admin@admin.com") do |u|
      u.password = "Password"
      u.password_confirmation = "Password"
    end
    RecordingStudioAbTests::Assignment.delete_all
    RecordingStudioAbTests::Goal.delete_all
    RecordingStudioAbTests::Variant.delete_all
    RecordingStudioAbTests::Experiment.delete_all
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
    create_running_experiment!(key: "pricing_run", target_key: "pricing_page")
    # Integration cookies persist across examples; clear AB cookies so eligibility
    # assertions are not polluted by a prior assignment request.
    cookies.delete(:_rsab_vid)
    cookies.delete(:_rsab_a)
    sign_in User.find_by!(email: "admin@admin.com")
  end

  test "bot user agent serves control with no assignment" do
    get demo_pricing_path, headers: { "User-Agent" => "Googlebot/2.1" }
    assert_response :success
    assert_select "#pricing-variant[data-variant=control]"
    assert_equal 0, RecordingStudioAbTests::Assignment.count
  end

  test "blank user agent serves control with no assignment" do
    get demo_pricing_path, headers: { "User-Agent" => "" }
    assert_response :success
    assert_equal 0, RecordingStudioAbTests::Assignment.count
  end

  test "prefetch headers serve control with no assignment" do
    [
      { "Sec-Purpose" => "prefetch" },
      { "Purpose" => "prefetch" },
      { "X-Sec-Purpose" => "prefetch" }
    ].each do |headers|
      RecordingStudioAbTests::Assignment.delete_all
      get demo_pricing_path, headers: headers.merge("User-Agent" => "Mozilla/5.0")
      assert_response :success
      assert_equal 0, RecordingStudioAbTests::Assignment.count, "expected no assignment for #{headers.inspect}"
    end
  end

  test "HEAD serves control with no assignment" do
    head demo_pricing_path, headers: { "User-Agent" => "Mozilla/5.0" }
    assert_response :success
    assert_equal 0, RecordingStudioAbTests::Assignment.count
  end

  test "consent denied serves control with no cookie writes" do
    with_ab_config(consent_resolver: ->(_req) { false }) do
      get demo_pricing_path, headers: { "User-Agent" => "Mozilla/5.0" }
      assert_response :success
      assert_select "#pricing-variant[data-variant=control]"
      assert_equal 0, RecordingStudioAbTests::Assignment.count
      refute cookies[:_rsab_vid].present?
    end
  end

  test "non-GET honours existing assignment and never creates" do
    get demo_pricing_path, headers: { "User-Agent" => "Mozilla/5.0" }
    assert_equal 1, RecordingStudioAbTests::Assignment.count
    variant = css_select("#pricing-variant").first["data-variant"]

    assert_no_difference -> { RecordingStudioAbTests::Assignment.count } do
      post demo_pricing_path, headers: { "User-Agent" => "Mozilla/5.0" }
      assert_response :success
      assert_select "#pricing-variant[data-variant=?]", variant
    end
  end

  test "enabled false serves control with no work" do
    with_ab_config(enabled: false) do
      get demo_pricing_path, headers: { "User-Agent" => "Mozilla/5.0" }
      assert_response :success
      assert_select "#pricing-variant[data-variant=control]"
      assert_equal 0, RecordingStudioAbTests::Assignment.count
    end
  end
end
