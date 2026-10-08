# frozen_string_literal: true

module RecordingStudioAbTests
  class EventDefinition
    VALID_SUBJECTS = %i[visitor user root_recording].freeze

    attr_reader :key, :label, :description, :subject, :value, :source, :notification, :map

    def initialize(key, label:, subject:, description: nil, value: false, source: :host,
                   notification: nil, map: nil)
      @key = key.to_sym
      @label = label
      @description = description
      @subject = subject.to_sym
      @value = value
      @source = source
      @notification = notification
      @map = map

      return if VALID_SUBJECTS.include?(@subject)

      raise InvalidEvent, "invalid event subject #{@subject.inspect} for #{@key}"
    end
  end
end
