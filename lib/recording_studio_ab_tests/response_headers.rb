# frozen_string_literal: true

module RecordingStudioAbTests
  # Marks the HTTP response private/no-store when a running experiment is evaluated
  # so shared caches (CDN) never serve personalized experiment HTML (plan §27).
  module ResponseHeaders
    module_function

    def mark_experiment_response!
      request = Current.request
      return unless request

      response = request_response(request)
      return unless response
      return unless response.respond_to?(:cache_control)

      response.cache_control[:private] = true
      response.cache_control[:no_store] = true
    rescue StandardError
      # Never break the host response over cache-control marking.
      nil
    end

    def request_response(request)
      controller = Current.controller
      if controller.nil? && request.env
        controller = request.env["action_controller.instance"]
        Current.controller = controller if controller
      end
      return controller.response if controller&.respond_to?(:response) && controller.response

      request.env&.fetch("action_dispatch.response", nil)
    end
    module_function :request_response
  end
end
