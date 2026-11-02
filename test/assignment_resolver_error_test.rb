# frozen_string_literal: true

require "test_helper"

class AssignmentResolverErrorTest < Minitest::Test
  def test_unknown_target_is_reraised
    assert_raises(RecordingStudioAbTests::UnknownTarget) do
      RecordingStudioAbTests::AssignmentResolver.resolve(:missing_target_for_failure_policy)
    end
  end

  def test_argument_error_is_reraised_when_raise_errors_is_off
    original = RecordingStudioAbTests.configuration.raise_errors
    RecordingStudioAbTests.configuration.raise_errors = false

    RecordingStudioAbTests.registry.stub(:fetch_target!, ->(*) { raise ArgumentError, "bad target" }) do
      error = assert_raises(ArgumentError) do
        RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page)
      end
      assert_equal "bad target", error.message
    end
  ensure
    RecordingStudioAbTests.configuration.raise_errors = original
  end
end
