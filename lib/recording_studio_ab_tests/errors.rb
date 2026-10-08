# frozen_string_literal: true

module RecordingStudioAbTests
  class Error < StandardError; end
  class UnknownTarget < Error; end
  class InvalidTarget < Error; end
  class InvalidEvent < Error; end
  class UnknownEvent < Error; end
  class LifecycleError < Error; end
end
