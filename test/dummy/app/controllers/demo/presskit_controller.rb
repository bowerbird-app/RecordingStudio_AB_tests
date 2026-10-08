# frozen_string_literal: true

module Demo
  class PresskitController < ApplicationController
    before_action :authenticate_user!

    def show
      @last_event_id = flash[:presskit_event_id]
    end

    def create
      event_id = SecureRandom.uuid
      RecordingStudioAbTests.track_event(
        :presskit_created,
        subject: current_user,
        event_id: event_id,
        occurred_at: Time.current,
        metadata: { source: "demo" }
      )
      flash[:presskit_event_id] = event_id
      redirect_to demo_presskit_path, notice: "Press kit tracked (event_id=#{event_id})"
    end
  end
end
