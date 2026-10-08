# frozen_string_literal: true

module RecordingStudioAbTests
  class Configuration
    attr_accessor :enabled,
                  :current_user_resolver,
                  :user_identifier,
                  :current_root_recording_resolver,
                  :consent_resolver,
                  :bot_user_agent_pattern,
                  :exposure_mode,
                  :exposure_queue,
                  :track_repeat_exposures,
                  :active_set_check_interval,
                  :cookie_reverify_after,
                  :max_cookie_entries,
                  :subscribe_to_user_registration,
                  :raise_errors,
                  :visitor_cookie_ttl,
                  :allow_force_param,
                  :mount_path
    attr_reader :hooks

    def initialize
      @enabled = true
      @current_user_resolver = ->(controller) { controller.try(:current_user) }
      @user_identifier = ->(user) { user.id.to_s }
      @current_root_recording_resolver = ->(controller) { controller.try(:current_root_recording) }
      @consent_resolver = ->(_request) { true }
      @bot_user_agent_pattern =
        /bot|crawl|spider|slurp|facebookexternalhit|preview|headless|lighthouse|monitor/i
      @exposure_mode = :async
      @exposure_queue = :default
      @track_repeat_exposures = false
      @active_set_check_interval = 5.seconds
      @cookie_reverify_after = 24.hours
      @max_cookie_entries = 15
      @subscribe_to_user_registration = true
      @raise_errors = defined?(Rails) && Rails.env.test?
      @visitor_cookie_ttl = 1.year
      @allow_force_param = false
      @mount_path = "/ab_tests"
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        enabled: enabled,
        exposure_mode: exposure_mode,
        exposure_queue: exposure_queue,
        track_repeat_exposures: track_repeat_exposures,
        active_set_check_interval: active_set_check_interval,
        cookie_reverify_after: cookie_reverify_after,
        max_cookie_entries: max_cookie_entries,
        subscribe_to_user_registration: subscribe_to_user_registration,
        raise_errors: raise_errors,
        visitor_cookie_ttl: visitor_cookie_ttl,
        allow_force_param: allow_force_param,
        mount_path: mount_path,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
