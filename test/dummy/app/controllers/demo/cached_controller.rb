# frozen_string_literal: true

module Demo
  class CachedController < ApplicationController
    skip_before_action :authenticate_user!

    def show
      @recording = current_root_recording || Workspace.first&.then { |w| RecordingStudio.root_recording_for(w) }
    end
  end
end
