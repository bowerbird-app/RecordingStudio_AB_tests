# frozen_string_literal: true

module RecordingStudioAbTests
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    protect_from_forgery with: :exception
  end
end
