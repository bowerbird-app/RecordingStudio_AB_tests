# frozen_string_literal: true

require "test_helper"

class AbUserClassTest < ActiveSupport::TestCase
  test "configuration user_class is the Users configured class" do
    assert_equal User, RecordingStudioAbTests.configuration.user_class
    assert_equal RecordingStudioUser.config.user_class, RecordingStudioAbTests.configuration.user_class
  end
end
