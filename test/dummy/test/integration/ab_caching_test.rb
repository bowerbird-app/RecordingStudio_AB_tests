# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbCachingTest < ActionDispatch::IntegrationTest
  include AbTestsHelper

  setup do
    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    @recording = RecordingStudio.root_recording_for(@workspace)
  end

  teardown do
    Rails.cache = @previous_cache if @previous_cache
  end

  test "ab_cache_vary keys differ per variant and omit visitor and user ids" do
    create_running_experiment!(key: "cache_a", target_key: "cached_hero", weights: [100, 0])

    get demo_cached_path, headers: BROWSER_UA
    assert_response :success
    control_vary = CGI.unescapeHTML(response.body[%r{id="ab-vary-key">([^<]+)</code>}, 1].to_s)
    assert_includes control_vary, '"ab.cached_hero"=>"control"'
    refute_includes control_vary, "visitor"
    refute_includes control_vary, "user_id"
    vid = RecordingStudioAbTests.current_visitor_id
    refute_includes(control_vary, vid) if vid.present?

    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    create_running_experiment!(key: "cache_b", target_key: "cached_hero", weights: [0, 100])
    reset!
    get demo_cached_path, headers: BROWSER_UA
    assert_response :success
    b_vary = CGI.unescapeHTML(response.body[%r{id="ab-vary-key">([^<]+)</code>}, 1].to_s)
    assert_includes b_vary, '"ab.cached_hero"=>"b"'
    refute_equal control_vary, b_vary
  end

  test "cache hit still records exposure" do
    create_running_experiment!(key: "cache_exp", target_key: "cached_hero", weights: [0, 100])

    with_ab_config(exposure_mode: :inline) do
      get demo_cached_path, headers: BROWSER_UA
      assert_response :success
      assert_select "#cached-hero-variant[data-variant=b]"
      assert_equal 1, RecordingStudioAbTests::Exposure.count

      # New visitor, same variant → fragment cache hit; ab_cache_vary still exposes first.
      reset!
      get demo_cached_path, headers: BROWSER_UA
      assert_response :success
      assert_select "#cached-hero-variant[data-variant=b]"
      assert_equal 2, RecordingStudioAbTests::Exposure.count
      assert_equal true, response.cache_control[:private]
      assert_equal true, response.cache_control[:no_store]
    end
  end

  test "leak demonstration: caching without ab_cache_vary serves wrong variant" do
    create_running_experiment!(key: "cache_leak", target_key: "cached_hero", weights: [0, 100])

    # Simulate a host bug: cache key omits ab_cache_vary.
    Rails.cache.write("leaky_hero_without_vary", %(<div id="leaked" data-variant="b">B</div>))

    clear_ab_tables!
    RecordingStudioAbTests::ActiveSet.clear_local!
    create_running_experiment!(key: "cache_leak2", target_key: "cached_hero", weights: [100, 0])
    leaked_hit = Rails.cache.fetch("leaky_hero_without_vary") { "should-not-run" }
    assert_includes leaked_hit, 'data-variant="b"'

    # Fix: include ab_cache_vary in the key (or use render_ab cache:).
    reset!
    get demo_cached_path, headers: BROWSER_UA
    assert_response :success
    assert_select "#cached-hero-variant[data-variant=control]"
    refute_includes response.body, 'id="leaked"'
  end

  test "RecordingStudioCache.fetch receives vary hash when available" do
    skip "RecordingStudioCache not loaded" unless defined?(RecordingStudioCache)

    create_running_experiment!(key: "cache_rsc", target_key: "cached_hero", weights: [50, 50])
    vary = { "ab.cached_hero" => "control" }
    calls = []
    original = RecordingStudioCache.method(:fetch)
    RecordingStudioCache.define_singleton_method(:fetch) do |recording, entry, **opts, &block|
      calls << { recording: recording, entry: entry, opts: opts }
      original.call(recording, entry, **opts, &block)
    end

    begin
      html = RecordingStudioAbTests::FragmentCache.fetch(
        { recording: @recording, entry: :cached_hero, policy: :default },
        vary: vary
      ) { "<p>ok</p>".html_safe }
      assert html.html_safe?
      assert_equal 1, calls.size
      assert_equal vary, calls.first[:opts][:vary]
      assert_equal :default, calls.first[:opts][:policy]
    ensure
      RecordingStudioCache.define_singleton_method(:fetch, original)
    end
  end
end
