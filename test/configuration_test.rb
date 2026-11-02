# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioAbTests::Configuration.new
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(enabled: false, max_cookie_entries: 9, exposure_mode: :inline)

    assert_equal false, @configuration.enabled
    assert_equal 9, @configuration.max_cookie_entries
    assert_equal :inline, @configuration.exposure_mode
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", max_cookie_entries: 7)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7, @configuration.max_cookie_entries
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original[:enabled], @configuration.enabled
    assert_equal original[:max_cookie_entries], @configuration.max_cookie_entries
  end

  def test_initialize_sets_ab_defaults
    configuration = RecordingStudioAbTests::Configuration.new

    assert_equal true, configuration.enabled
    assert_equal :async, configuration.exposure_mode
    assert_equal 15, configuration.max_cookie_entries
    assert_equal "/ab_tests", configuration.mount_path
    assert_instance_of RecordingStudio::Hooks, configuration.hooks
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("enabled" => false, "max_cookie_entries" => 12)

    assert_equal false, @configuration.enabled
    assert_equal 12, @configuration.max_cookie_entries
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioAbTests.configure

    assert_kind_of RecordingStudioAbTests::Configuration, RecordingStudioAbTests.configuration
  end
end
