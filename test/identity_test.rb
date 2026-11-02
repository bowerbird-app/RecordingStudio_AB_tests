# frozen_string_literal: true

require "test_helper"

class IdentityTest < Minitest::Test
  def setup
    RecordingStudioAbTests::Current.reset
  end

  def teardown
    RecordingStudioAbTests::Current.reset
  end

  def test_visitor_id_reuses_current_value
    RecordingStudioAbTests::Current.visitor_id = "already-set"

    assert_equal "already-set", RecordingStudioAbTests::Identity.visitor_id
  end

  def test_visitor_id_is_nil_without_root_switchable_device_key
    skip "Root Switchable is loaded" if defined?(RecordingStudio::RootSwitchable::DeviceKey)

    assert_nil RecordingStudioAbTests::Identity.visitor_id(create: true)
  end
end
