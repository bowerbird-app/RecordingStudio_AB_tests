# frozen_string_literal: true

module RecordingStudioAbTests
  class AssignmentResolver
    Resolution = Struct.new(
      :variant_key, :implementation_key, :assignment, :experiment_id, :reason,
      :rails_variant, :created, keyword_init: true
    )

    class << self
      def resolve(target_key, expose: true)
        target = RecordingStudioAbTests.registry.fetch_target!(target_key)
        return control_resolution(reason: :invalid_target) unless target.valid?

        entry = ActiveSet.experiment_for(target.key)
        return control_resolution(reason: :inactive) unless entry && entry[:status] == "running"

        request = Current.request
        eligibility = Eligibility.evaluate(request: request, experiment: OpenStructExperiment.new(entry))
        unless eligibility.eligible?
          if eligibility.allow_existing_read
            existing = read_existing(entry, create_visitor: false)
            return existing if existing
          end
          return control_resolution(reason: eligibility.reason)
        end

        subject = Identity.resolve_subject(
          OpenStructExperiment.new(entry),
          create_visitor: true
        )
        return control_resolution(reason: :no_subject) unless subject

        unless Allocator.in_traffic?(
          experiment: OpenStructExperiment.new(entry),
          subject_type: subject[:subject_type],
          subject_identifier: subject[:subject_identifier]
        )
          return control_resolution(reason: :traffic_gate)
        end

        memo_key = memo_key_for(entry[:id], subject)
        if (memo = Current.assignments[memo_key])
          maybe_expose(entry, target, memo, expose)
          return memo
        end

        resolution =
          if anonymous_cookie_path?(entry, subject)
            resolve_anonymous(entry, target, subject, expose: expose)
          else
            resolve_database(entry, target, subject, expose: expose)
          end

        Current.assignments[memo_key] = resolution
        resolution
      rescue UnknownTarget
        raise
      rescue StandardError => e
        handle_error(e)
      end

      private

      def anonymous_cookie_path?(entry, subject)
        subject[:subject_type] == "visitor" &&
          (entry[:assignment_scope] == "visitor" ||
            (entry[:assignment_scope] == "user" && Current.user_identifier.blank?))
      end

      def resolve_anonymous(entry, target, subject, expose:)
        payload = CookieCodec.read(Current.request)
        if cookie_hit?(payload, entry, subject)
          variant_key = CookieCodec.entry_for(payload, entry[:id]).first
          variant = entry[:variants].find { |v| v[:key] == variant_key }
          if variant
            resolution = build_resolution(entry, variant, assignment: nil, reason: :cookie, created: false)
            maybe_expose(entry, target, resolution, expose)
            return resolution
          end
        end

        resolve_database(entry, target, subject, expose: expose, write_cookie: true)
      end

      def cookie_hit?(payload, entry, subject)
        return false unless CookieCodec.fresh?(payload)
        return false unless payload["vid"].to_s == subject[:subject_identifier].to_s

        entry_data = CookieCodec.entry_for(payload, entry[:id])
        return false unless entry_data.is_a?(Array) && entry_data[0].present?

        entry[:variants].any? { |v| v[:key] == entry_data[0].to_s }
      end

      def resolve_database(entry, target, subject, expose:, write_cookie: false)
        existing = find_assignment(entry[:id], subject)
        if existing
          variant = entry[:variants].find { |v| v[:id] == existing.variant_id }
          resolution = build_resolution(entry, variant || control_variant(entry),
                                        assignment: existing, reason: :db, created: false)
          write_cookie_from!(entry, resolution, subject) if write_cookie
          maybe_expose(entry, target, resolution, expose)
          return resolution
        end

        variant_bucket = Allocator.variant_bucket(
          experiment: OpenStructExperiment.new(entry),
          subject_type: subject[:subject_type],
          subject_identifier: subject[:subject_identifier]
        )
        chosen = Allocator.choose_variant(
          entry[:variants].map { |v| VariantProxy.new(v) },
          variant_bucket
        )

        attrs = {
          id: SecureRandom.uuid,
          experiment_id: entry[:id],
          variant_id: chosen.id,
          subject_type: subject[:subject_type],
          subject_identifier: subject[:subject_identifier],
          root_recording_id: Current.root_recording_id,
          allocation_version: entry[:allocation_version],
          bucket: variant_bucket,
          assigned_at: Time.current,
          created_at: Time.current,
          updated_at: Time.current
        }

        if Current.user_identifier.present? && subject[:subject_type] == "visitor"
          attrs[:linked_user_id] = Current.user_identifier
          attrs[:linked_at] = Time.current
          attrs[:link_source] = "authenticated_request"
        end

        RecordingStudioAbTests::Assignment.insert_all(
          [attrs],
          unique_by: :idx_rsab_assignments_subject
        )

        assignment = find_assignment(entry[:id], subject)
        variant = entry[:variants].find { |v| v[:id] == assignment.variant_id }
        resolution = build_resolution(entry, variant,
                                      assignment: assignment, reason: :assigned, created: true)
        write_cookie_from!(entry, resolution, subject) if write_cookie || anonymous_cookie_path?(entry, subject)
        maybe_expose(entry, target, resolution, expose)
        resolution
      end

      def read_existing(entry, create_visitor:)
        subject = Identity.resolve_subject(
          OpenStructExperiment.new(entry),
          create_visitor: create_visitor
        )
        return nil unless subject

        memo_key = memo_key_for(entry[:id], subject)
        return Current.assignments[memo_key] if Current.assignments[memo_key]

        if anonymous_cookie_path?(entry, subject)
          payload = CookieCodec.read(Current.request)
          if cookie_hit?(payload, entry, subject)
            variant_key = CookieCodec.entry_for(payload, entry[:id]).first
            variant = entry[:variants].find { |v| v[:key] == variant_key }
            return build_resolution(entry, variant, assignment: nil, reason: :cookie, created: false) if variant
          end
        end

        assignment = find_assignment(entry[:id], subject)
        return nil unless assignment

        variant = entry[:variants].find { |v| v[:id] == assignment.variant_id }
        build_resolution(entry, variant, assignment: assignment, reason: :db, created: false)
      end

      def find_assignment(experiment_id, subject)
        RecordingStudioAbTests::Assignment.find_by(
          experiment_id: experiment_id,
          subject_type: subject[:subject_type],
          subject_identifier: subject[:subject_identifier]
        )
      end

      def write_cookie_from!(entry, resolution, subject)
        return unless Current.request
        return unless subject[:subject_type] == "visitor"

        payload = CookieCodec.read(Current.request)
        payload = CookieCodec.put_entry(
          payload,
          experiment_id: entry[:id],
          variant_key: resolution.variant_key,
          target_key: entry[:target_key],
          visitor_id: subject[:subject_identifier]
        )
        active_ids = ActiveSet.current[:by_target].values.map { |e| e[:id] }
        payload = CookieCodec.evict!(payload, active_experiment_ids: active_ids)
        CookieCodec.write!(Current.request, payload)
      end

      def maybe_expose(entry, target, resolution, expose)
        return unless expose
        return if resolution.variant_key.to_s == "control" && resolution.reason == :inactive

        key = "#{entry[:id]}:#{target.key}"
        return if Current.exposed.include?(key)

        Current.exposed << key
        # Full exposure persistence lands in PR2; PR1 records in-request only.
        ActiveSupport::Notifications.instrument(
          "exposure.recording_studio_ab_tests",
          experiment_id: entry[:id],
          target_key: target.key,
          variant_key: resolution.variant_key,
          assignment_id: resolution.assignment&.id
        )
      end

      def build_resolution(entry, variant, assignment:, reason:, created:)
        variant ||= control_variant(entry)
        Resolution.new(
          variant_key: variant[:key] || variant.key,
          implementation_key: variant[:implementation_key] || variant.implementation_key,
          assignment: assignment,
          experiment_id: entry[:id],
          reason: reason,
          rails_variant: nil,
          created: created
        ).tap do |resolution|
          target = RecordingStudioAbTests.registry.target(entry[:target_key])
          resolution.rails_variant = target&.rails_variant_for(resolution.variant_key)
        end
      end

      def control_variant(entry)
        entry[:variants].find { |v| v[:is_control] } || entry[:variants].first ||
          { key: "control", implementation_key: "control", is_control: true }
      end

      def control_resolution(reason:)
        Resolution.new(
          variant_key: "control",
          implementation_key: "control",
          assignment: nil,
          experiment_id: nil,
          reason: reason,
          rails_variant: nil,
          created: false
        )
      end

      def memo_key_for(experiment_id, subject)
        "#{experiment_id}:#{subject[:subject_type]}:#{subject[:subject_identifier]}"
      end

      def handle_error(error)
        ActiveSupport::Notifications.instrument(
          "resolution_error.recording_studio_ab_tests",
          error: error
        )
        raise error if RecordingStudioAbTests.configuration.raise_errors

        control_resolution(reason: :error)
      end
    end

    # Lightweight experiment-shaped object for Allocator/Identity/Eligibility
    class OpenStructExperiment
      def initialize(entry)
        @entry = entry
      end

      def id = @entry[:id]
      def key = @entry[:key]
      def status = @entry[:status]
      def assignment_scope = @entry[:assignment_scope]
      def traffic_percentage = @entry[:traffic_percentage]
      def allocation_seed = @entry[:allocation_seed]
      def allocation_version = @entry[:allocation_version]
      def scope_root_recording_id = @entry[:scope_root_recording_id]
      def target_key = @entry[:target_key]
    end

    class VariantProxy
      def initialize(hash)
        @hash = hash
      end

      def id = @hash[:id]
      def key = @hash[:key]
      def weight = @hash[:weight]
      def position = @hash[:position]

      def is_control
        @hash[:is_control]
      end

      def implementation_key = @hash[:implementation_key]
    end
  end
end
