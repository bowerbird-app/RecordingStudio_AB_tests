# frozen_string_literal: true

module RecordingStudioAbTests
  # Applies an explicit subject to Current for out-of-request execute/expose.
  module SubjectContext
    module_function

    def with(subject)
      return yield if subject.nil?

      previous = snapshot
      begin
        apply!(subject)
        yield
      ensure
        restore!(previous)
      end
    end

    def apply!(subject)
      if subject.respond_to?(:ab_subject_kind) && subject.ab_subject_kind == :visitor
        Current.visitor_id = subject.id.to_s
        return
      end

      if defined?(RecordingStudio::Recording) && subject.is_a?(RecordingStudio::Recording)
        Current.root_recording_id = subject.id.to_s
        return
      end

      if subject.respond_to?(:id)
        Current.user_identifier = RecordingStudioAbTests.configuration.user_identifier.call(subject).to_s
        return
      end

      Current.user_identifier = subject.to_s
    end

    def snapshot
      {
        visitor_id: Current.visitor_id,
        user_identifier: Current.user_identifier,
        root_recording_id: Current.root_recording_id
      }
    end
    module_function :snapshot

    def restore!(previous)
      Current.visitor_id = previous[:visitor_id]
      Current.user_identifier = previous[:user_identifier]
      Current.root_recording_id = previous[:root_recording_id]
    end
    module_function :restore!
  end
end
