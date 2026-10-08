# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbWorkflowTest < ActionDispatch::IntegrationTest
  include AbTestsHelper

  setup do
    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
  end

  test "workflow keeps one sticky variant across steps" do
    create_running_experiment!(key: "flow_run", target_key: "onboarding_flow", weights: [0, 100])

    get demo_flow_path(step: 1), headers: BROWSER_UA
    assert_response :success
    assert_select "#flow-variant[data-variant=b][data-step=1]"

    get demo_flow_path(step: 2), headers: BROWSER_UA
    assert_response :success
    assert_select "#flow-variant[data-variant=b][data-step=2]"

    get demo_flow_path(step: 3), headers: BROWSER_UA
    assert_response :success
    assert_select "#flow-variant[data-variant=b][data-step=3]"

    assert_equal 1, RecordingStudioAbTests::Assignment.count
  end
end
