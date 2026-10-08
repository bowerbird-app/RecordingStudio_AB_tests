# frozen_string_literal: true

module RecordingStudioAbTests
  module Identity
    VISITOR_COOKIE = :_rsab_vid

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

      request = Current.request
      return nil unless request

      jar = request.cookie_jar.signed
      existing = jar[VISITOR_COOKIE]
      if existing.present?
        Current.visitor_id = existing.to_s
        return Current.visitor_id
      end

      return nil unless create

      id = SecureRandom.uuid
      write_visitor_cookie!(id)
      Current.visitor_id = id
      id
    rescue StandardError
      # Tampered/invalid cookie → treat as absent
      return nil unless create

      id = SecureRandom.uuid
      write_visitor_cookie!(id)
      Current.visitor_id = id
      id
    end

    def write_visitor_cookie!(id)
      request = Current.request
      return unless request

      config = RecordingStudioAbTests.configuration
      request.cookie_jar.signed[VISITOR_COOKIE] = {
        value: id,
        httponly: true,
        same_site: :lax,
        secure: defined?(Rails) && Rails.env.production?,
        expires: config.visitor_cookie_ttl.from_now
      }
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
  end
end
