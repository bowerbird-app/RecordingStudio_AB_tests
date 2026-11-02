# frozen_string_literal: true

module RecordingStudioAbTests
  module FailurePolicy
    module_function

    def rescued_errors
      errors = []
      errors << ActiveRecord::ActiveRecordError if defined?(ActiveRecord::ActiveRecordError)
      errors << Redis::BaseError if defined?(Redis::BaseError)
      errors
    end
  end
end
