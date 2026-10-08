# frozen_string_literal: true

module RecordingStudioAbTests
  # Stores the ActionDispatch::Request on Current for helpers and subscribers.
  # Performs no DB work, cookie writes, or assignment.
  class RequestContext
    def initialize(app)
      @app = app
    end

    def call(env)
      Current.request = ActionDispatch::Request.new(env)
      @app.call(env)
    end
  end
end
