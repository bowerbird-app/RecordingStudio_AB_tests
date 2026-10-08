# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbAdaptersTest < ActionDispatch::IntegrationTest
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
    sign_in User.find_by!(email: "admin@admin.com")
  end

  test "view adapter renders control when inactive and variant when assigned" do
    get demo_pricing_path
    assert_response :success
    assert_select "#pricing-variant[data-variant=control]"

    create_running_experiment!(key: "pricing_run", target_key: "pricing_page", weights: [0, 100])
    get demo_pricing_path
    assert_response :success
    assert_select "#pricing-variant[data-variant=b]"
  end

  test "component adapter renders control and variant B" do
    get demo_hero_path
    assert_response :success
    assert_select "#hero-variant[data-variant=control]"

    create_running_experiment!(key: "hero_run", target_key: "hero_component", weights: [0, 100])
    get demo_hero_path
    assert_response :success
    assert_select "#hero-variant[data-variant=b]"
  end

  test "request.variant and view paths remain untouched" do
    create_running_experiment!(key: "pricing_run", target_key: "pricing_page", weights: [0, 100])

    controller = Demo::PricingController.new
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/demo/pricing", "HTTP_USER_AGENT" => "Mozilla/5.0"))
    response = ActionDispatch::Response.new
    controller.set_request!(request)
    controller.set_response!(response)
    RecordingStudioAbTests::Current.request = request
    RecordingStudioAbTests::Current.controller = controller

    before_paths = controller.view_paths.map(&:to_s)
    before_variant = request.variant.dup

    # Drive the adapter the same way the action does
    controller.define_singleton_method(:render) do |**opts|
      @_render_opts = opts
      self.response_body = "ok"
    end
    RecordingStudioAbTests::Adapters::View.render(controller, RecordingStudioAbTests.registry.fetch_target!(:pricing_page))

    assert_equal before_variant, request.variant
    assert_equal before_paths, controller.view_paths.map(&:to_s)
    assert_equal [:ab_pricing_b], controller.instance_variable_get(:@_render_opts)[:variants]
  end

  test "unknown target raises" do
    assert_raises(RecordingStudioAbTests::UnknownTarget) do
      RecordingStudioAbTests.registry.fetch_target!(:not_registered)
    end
  end
end
