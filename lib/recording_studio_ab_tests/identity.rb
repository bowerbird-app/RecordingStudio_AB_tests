# frozen_string_literal: true

module RecordingStudioAbTests
  module Identity
    COOKIE_READ_ERRORS = [
      JSON::ParserError,
      ActiveSupport::MessageVerifier::InvalidSignature,
      ActiveSupport::MessageEncryptor::InvalidMessage
    ].freeze

    module_function

    def resolve_subject(experiment, create_visitor: true)
      case experiment.assignment_scope
      when "visitor"
        vid = visitor_id(create: create_visitor)
        return nil unless vid

        { subject_type: "visitor", subject_identifier: vid }
      when "user"
        uid = Current.user_identifier || resolve_user_identifier
        if uid
          Current.user_identifier = uid
          { subject_type: "user", subject_identifier: uid }
        else
          vid = visitor_id(create: create_visitor)
          return nil unless vid

          { subject_type: "visitor", subject_identifier: vid }
        end
      when "root_recording"
        rid = Current.root_recording_id || resolve_root_recording_id
        return nil unless rid

        Current.root_recording_id = rid.to_s
        { subject_type: "root_recording", subject_identifier: rid.to_s }
      end
    end

    def visitor_id(create: true)
      return Current.visitor_id if Current.visitor_id.present?

      existing = existing_device_key
      if existing.present?
        Current.visitor_id = existing.to_s
        return Current.visitor_id
      end

      return nil unless create

      fetched = fetch_device_key
      return nil if fetched.blank?

      Current.visitor_id = fetched.to_s
      Current.visitor_id
    rescue *COOKIE_READ_ERRORS
      nil
    end

    def resolve_user_identifier
      controller = Current.controller
      return nil unless controller

      user = RecordingStudioAbTests.configuration.current_user_resolver.call(controller)
      return nil unless user

      RecordingStudioAbTests.configuration.user_identifier.call(user)
    end

    def resolve_root_recording_id
      controller = Current.controller
      return nil unless controller

      recording = RecordingStudioAbTests.configuration.current_root_recording_resolver.call(controller)
      return nil unless recording

      recording.try(:id) || recording
    end

    def populate_from_controller!(controller)
      Current.controller = controller
      Current.user_identifier ||= resolve_user_identifier
      Current.root_recording_id ||= resolve_root_recording_id&.to_s
    end

    def existing_device_key
      if defined?(RecordingStudio::RootSwitchable::Current)
        present = RecordingStudio::RootSwitchable::Current.device_key
        return present.to_s if present.present?
      end

      read_device_key_cookie
    end

    def fetch_device_key
      return unless defined?(RecordingStudio::RootSwitchable::DeviceKey)

      RecordingStudio::RootSwitchable::DeviceKey.fetch(
        controller: Current.controller,
        cookies: Current.request&.cookie_jar
      )
    rescue RecordingStudio::RootSwitchable::DeviceKey::Unavailable
      nil
    end

    def read_device_key_cookie
      return unless defined?(RecordingStudioRootSwitchable)
      return unless Current.request

      cookie_name = RecordingStudioRootSwitchable.configuration.device_key_cookie_name
      jar = Current.request.cookie_jar
      encrypted_jar = jar.respond_to?(:encrypted) ? jar.encrypted : jar
      encrypted_jar[cookie_name].presence
    end
  end
end
