# frozen_string_literal: true

module RecordingStudioAbTests
  # Subscribes once per notification name for registered events that declare notification: + map:.
  module EventSubscriptions
    USER_REGISTERED_EVENT = "registration.completed.recording_studio_user"

    class << self
      def install!
        @installed_notifications ||= Set.new
        ensure_builtin_user_registered!
        RecordingStudioAbTests.registry.events.each_value { |event| subscribe_event!(event) }
      end

      def reset!
        Array(@subscribers).each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
        @subscribers = []
        @installed_notifications = Set.new
        @builtin_registered = false
      end

      private

      def ensure_builtin_user_registered!
        return unless RecordingStudioAbTests.configuration.subscribe_to_user_registration
        return if @builtin_registered

        RecordingStudioAbTests.register_event :user_registered,
          label: "User registered",
          subject: :user,
          source: :notification,
          notification: USER_REGISTERED_EVENT,
          map: lambda { |payload|
            {
              subject_identifier: payload[:user_id].to_s,
              event_id: "user:#{payload[:user_id]}",
              metadata: { method: payload[:method].to_s }
            }
          }

        @builtin_registered = true
      end

      def subscribe_event!(event)
        return if event.notification.blank? || event.map.nil?

        name = event.notification.to_s
        return if @installed_notifications.include?(name)

        @installed_notifications << name
        @subscribers ||= []
        @subscribers << ActiveSupport::Notifications.subscribe(name) do |_n, _s, _f, _id, payload|
          handle_notification!(name, payload)
        end
      end

      def handle_notification!(notification_name, payload)
        events = RecordingStudioAbTests.registry.events.values.select do |event|
          event.notification.to_s == notification_name
        end

        events.each do |event|
          mapped = event.map.call(payload || {})
          next unless mapped.is_a?(Hash)

          subject_identifier = mapped[:subject_identifier] || mapped["subject_identifier"]
          next if subject_identifier.blank?

          maybe_link_from_registration!(event, payload, subject_identifier)

          RecordingStudioAbTests.track_event(
            event.key,
            subject: subject_for(event.subject, subject_identifier),
            event_id: mapped[:event_id] || mapped["event_id"],
            value: mapped[:value] || mapped["value"],
            occurred_at: mapped[:occurred_at] || mapped["occurred_at"] || Time.current,
            metadata: mapped[:metadata] || mapped["metadata"] || {}
          )
        end
      rescue StandardError => e
        ActiveSupport::Notifications.instrument(
          "conversion_failed.recording_studio_ab_tests",
          error: e,
          notification: notification_name
        )
        Rails.logger.error("[RecordingStudioAbTests] notification handler failed: #{e.class}: #{e.message}")
        raise if RecordingStudioAbTests.configuration.raise_errors
      end

      def maybe_link_from_registration!(event, payload, subject_identifier)
        return unless event.key == :user_registered
        return unless notification_in_request?

        visitor_id = Current.request.cookie_jar.signed[Identity::VISITOR_COOKIE]
        return if visitor_id.blank?

        user = find_user(payload[:user_id] || subject_identifier)
        return unless user

        IdentityLinker.link!(
          visitor_id: visitor_id,
          user: user,
          source: "registration.completed"
        )
      end

      def notification_in_request?
        Current.request.present?
      end

      def find_user(user_id)
        return if user_id.blank?
        return unless defined?(User)

        User.find_by(id: user_id)
      end

      def subject_for(kind, identifier)
        case kind.to_sym
        when :user
          return User.find_by(id: identifier) if defined?(User)

          Struct.new(:id).new(identifier)
        when :visitor
          RecordingStudioAbTests.visitor(identifier)
        when :root_recording
          if defined?(RecordingStudio::Recording)
            RecordingStudio::Recording.find_by(id: identifier) || Struct.new(:id).new(identifier)
          else
            Struct.new(:id).new(identifier)
          end
        else
          Struct.new(:id).new(identifier)
        end
      end
    end
  end
end
