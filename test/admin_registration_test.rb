# frozen_string_literal: true

require "test_helper"

class AdminRegistrationTest < Minitest::Test
  def test_admin_module_file_exists
    path = File.expand_path("../lib/recording_studio_ab_tests/admin.rb", __dir__)
    assert File.file?(path)
  end

  def test_register_is_noop_without_recording_studio_admin
    # Soft optional: engine gates on defined?(RecordingStudioAdmin).
    source = File.read(File.expand_path("../lib/recording_studio_ab_tests/engine.rb", __dir__))
    assert_includes source, "defined?(RecordingStudioAdmin)"
    assert_includes source, 'require "recording_studio_ab_tests/admin"'
    assert_includes source, "RecordingStudioAbTests::Admin.register!"
  end

  def test_metrics_module_file_exists
    path = File.expand_path("../lib/recording_studio_ab_tests/metrics.rb", __dir__)
    assert File.file?(path)
  end
end
