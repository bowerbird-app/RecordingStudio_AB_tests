# frozen_string_literal: true

module Demo
  class FlowController < ApplicationController
    skip_before_action :authenticate_user!

    STEPS = {
      "1" => "onboarding/steps/details",
      "2" => "onboarding/steps/preferences",
      "3" => "onboarding/steps/confirm"
    }.freeze

    def show
      @step = params[:step].to_s
      @partial = STEPS[@step]
      raise ActionController::RoutingError, "Unknown flow step" unless @partial
    end
  end
end
