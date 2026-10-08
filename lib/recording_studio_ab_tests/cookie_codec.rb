# frozen_string_literal: true

module RecordingStudioAbTests
  module CookieCodec
    COOKIE_NAME = :_rsab_a
    VERSION = 1

    module_function

    def read(request)
      return empty_payload unless request

      raw = request.cookie_jar.signed[COOKIE_NAME]
      return empty_payload if raw.blank?

      payload = raw.is_a?(Hash) ? raw.deep_stringify_keys : JSON.parse(raw.to_s)
      return empty_payload unless payload["v"].to_i == VERSION

      payload
    rescue StandardError
      empty_payload
    end

    def write!(request, payload)
      return unless request

      config = RecordingStudioAbTests.configuration
      request.cookie_jar.signed[COOKIE_NAME] = {
        value: payload,
        httponly: true,
        same_site: :lax,
        secure: defined?(Rails) && Rails.env.production?,
        expires: config.visitor_cookie_ttl.from_now
      }
    end

    def entry_for(payload, experiment_id)
      payload.dig("a", experiment_id.to_s)
    end

    def put_entry(payload, experiment_id:, variant_key:, target_key:, visitor_id:)
      payload = payload.deep_dup
      payload["v"] = VERSION
      payload["vid"] = visitor_id
      payload["ts"] = Time.current.to_i
      payload["a"] ||= {}
      existing = payload["a"][experiment_id.to_s]
      targets = existing.is_a?(Array) && existing[1].is_a?(Array) ? existing[1] : []
      targets = (targets + [target_key.to_s]).uniq
      payload["a"][experiment_id.to_s] = [variant_key.to_s, targets]
      payload
    end

    def evict!(payload, active_experiment_ids:)
      config = RecordingStudioAbTests.configuration
      assignments = payload["a"] || {}
      return payload if assignments.size <= config.max_cookie_entries

      active = active_experiment_ids.map(&:to_s)
      # Evict inactive first, then oldest by iterating insertion order
      inactive_keys = assignments.keys.reject { |k| active.include?(k) }
      inactive_keys.each do |key|
        assignments.delete(key)
        break if assignments.size <= config.max_cookie_entries
      end

      assignments.delete(assignments.keys.first) while assignments.size > config.max_cookie_entries

      payload["a"] = assignments
      payload
    end

    def fresh?(payload)
      ts = payload["ts"].to_i
      return false if ts <= 0

      age = Time.current.to_i - ts
      age < RecordingStudioAbTests.configuration.cookie_reverify_after.to_i
    end

    def empty_payload
      { "v" => VERSION, "vid" => nil, "ts" => 0, "a" => {} }
    end
  end
end
