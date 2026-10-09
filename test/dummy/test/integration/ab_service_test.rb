# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbServiceTest < ActionDispatch::IntegrationTest
  include AbTestsHelper
  include Devise::Test::IntegrationHelpers

  setup do
    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    Rails.cache.clear
  end

  test "execute selects control when inactive and variant B when assigned" do
    get demo_quote_path(amount: 100), headers: BROWSER_UA
    assert_response :success
    assert_select "#quote-variant[data-variant=control]"

    create_running_experiment!(key: "quote_run", target_key: "quote_strategy", weights: [ 0, 100 ])
    get demo_quote_path(amount: 100), headers: BROWSER_UA
    assert_response :success
    assert_select "#quote-variant[data-variant=b]"
    assert_match(/Promotional quote/, response.body)
  end

  test "execute enforces service-only contract" do
    error = assert_raises(ArgumentError) do
      RecordingStudioAbTests.execute(:pricing_page, amount: 1)
    end
    assert_match(/service targets/, error.message)
  end

  test "lifecycle start requires service .call" do
    RecordingStudioAbTests.register_target :bad_service,
      type: :service,
      control: "String",
      variants: { b: "Integer" }

    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "bad_svc",
      name: "Bad",
      target_key: "bad_service",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "abcd1234efgh5678",
      allocation_version: "sha256-v1",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "C", implementation_key: "control",
                                is_control: true, weight: 50, position: 0)
    experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                is_control: false, weight: 50, position: 1)
    experiment.goals.create!(key: "primary", name: "P", event_key: "demo_signup", is_primary: true)

    error = assert_raises(RecordingStudioAbTests::LifecycleError) do
      RecordingStudioAbTests::Lifecycle.start!(experiment)
    end
    assert_match(/\.call/, error.message)
  ensure
    RecordingStudioAbTests.registry.instance_variable_get(:@targets)&.delete(:bad_service)
  end

  test "running experiment response is private no-store" do
    create_running_experiment!(key: "quote_priv", target_key: "quote_strategy", weights: [ 100, 0 ])
    get demo_quote_path, headers: BROWSER_UA
    assert_response :success
    assert_equal true, response.cache_control[:private]
    assert_equal true, response.cache_control[:no_store]
  end
end
