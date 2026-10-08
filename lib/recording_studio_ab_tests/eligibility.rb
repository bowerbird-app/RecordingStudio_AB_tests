# frozen_string_literal: true

module RecordingStudioAbTests
  module Eligibility
    module_function

    Result = Struct.new(:eligible, :reason, :allow_existing_read, keyword_init: true) do
      def eligible?
        eligible
      end
    end

    def evaluate(request:, experiment: nil)
      config = RecordingStudioAbTests.configuration

      return Result.new(eligible: false, reason: :disabled, allow_existing_read: false) unless config.enabled

      if experiment&.scope_root_recording_id.present?
        current_root = Current.root_recording_id
        unless current_root.to_s == experiment.scope_root_recording_id.to_s
          return Result.new(eligible: false, reason: :scope_mismatch, allow_existing_read: false)
        end
      end

      if request && !config.consent_resolver.call(request)
        return Result.new(eligible: false, reason: :consent_denied, allow_existing_read: false)
      end

      return Result.new(eligible: false, reason: :bot, allow_existing_read: false) if bot?(request)

      return Result.new(eligible: false, reason: :prefetch, allow_existing_read: false) if prefetch?(request)

      return Result.new(eligible: false, reason: :head, allow_existing_read: false) if request&.head?

      return Result.new(eligible: false, reason: :non_get, allow_existing_read: true) if request && !request.get?

      Result.new(eligible: true, reason: :ok, allow_existing_read: true)
    end

    def bot?(request)
      return true unless request

      ua = request.user_agent.to_s
      return true if ua.blank?

      ua.match?(RecordingStudioAbTests.configuration.bot_user_agent_pattern)
    end

    def prefetch?(request)
      return false unless request

      %w[Sec-Purpose Purpose X-Sec-Purpose].any? do |header|
        value = request.get_header(header_env(header)).to_s
        value.downcase.include?("prefetch")
      end
    end

    def header_env(name)
      "HTTP_#{name.tr('-', '_').upcase}"
    end
  end
end
