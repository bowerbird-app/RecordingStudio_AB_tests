# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbForceParamTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include AbTestsHelper

  setup do
    User.find_or_create_by!(email: "admin@admin.com") do |u|
      u.password = "Password"
      u.password_confirmation = "Password"
    end
    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
    create_running_experiment!(key: "force_pricing_#{SecureRandom.hex(4)}", target_key: "pricing_page")
    RecordingStudioAbTests.configuration.allow_force_param = true
    sign_in User.find_by!(email: "admin@admin.com")
  end

  teardown do
    RecordingStudioAbTests.configuration.allow_force_param = Rails.env.local?
  end

  test "ab_force selects variant B without creating an assignment" do
    before = RecordingStudioAbTests::Assignment.count
    get demo_pricing_path, params: { ab_force: "b" }, headers: BROWSER_UA
    assert_response :success
    assert_select "#pricing-variant[data-variant=b]"
    assert_equal before, RecordingStudioAbTests::Assignment.count
  end

  test "ab_force selects control" do
    get demo_pricing_path, params: { ab_force: "control" }, headers: BROWSER_UA
    assert_response :success
    assert_select "#pricing-variant[data-variant=control]"
  end
end
