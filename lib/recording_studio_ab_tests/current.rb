# frozen_string_literal: true

module RecordingStudioAbTests
  class Current < ActiveSupport::CurrentAttributes
    attribute :request, :visitor_id, :user_identifier, :root_recording_id
    attribute :assignments, :exposed, :controller

    def assignments
      super || (self.assignments = {})
    end

    def exposed
      super || (self.exposed = Set.new)
    end
  end
end
