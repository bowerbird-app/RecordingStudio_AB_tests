# frozen_string_literal: true

module RecordingStudioAbTests
  class ActiveSet
    CACHE_KEY = "recording_studio_ab_tests/active_set_version"
    LIVE_STATUSES = %w[running paused].freeze
    GOAL_STATUSES = %w[running paused completed].freeze

    class << self
      def current
        ensure_fresh!
        @snapshot
      end

      def experiment_for(target_key)
        current[:by_target][target_key.to_s]
      end

      def bump!
        token = SecureRandom.uuid
        Rails.cache.write(CACHE_KEY, token)
        clear_local!
        token
      end

      def clear_local!
        @snapshot = nil
        @local_version = nil
        @checked_at = nil
      end

      def reload!
        clear_local!
        current
      end

      private

      def ensure_fresh!
        interval = RecordingStudioAbTests.configuration.active_set_check_interval
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return if @snapshot && @checked_at && (now - @checked_at) < interval.to_f

        @checked_at = now
        remote_version = Rails.cache.read(CACHE_KEY)
        return if @snapshot && @local_version == remote_version && remote_version

        @snapshot = build_snapshot
        @local_version = remote_version || SecureRandom.uuid
        Rails.cache.write(CACHE_KEY, @local_version) unless remote_version
      end

      def build_snapshot
        experiments = RecordingStudioAbTests::Experiment
                      .where(status: GOAL_STATUSES)
                      .includes(:variants, :goals)
                      .to_a

        by_target = {}
        by_id = {}
        goals_by_event = Hash.new { |h, k| h[k] = [] }

        experiments.each do |experiment|
          entry = freeze_experiment(experiment)
          by_id[experiment.id] = entry
          by_target[experiment.target_key] = entry if LIVE_STATUSES.include?(experiment.status)

          experiment.goals.each do |goal|
            goals_by_event[goal.event_key] << {
              goal_id: goal.id,
              experiment_id: experiment.id,
              key: goal.key,
              is_primary: goal.is_primary,
              attribution_window_hours: goal.attribution_window_hours,
              counting_policy: goal.counting_policy,
              status: experiment.status
            }.freeze
          end
        end

        {
          by_target: by_target.freeze,
          by_id: by_id.freeze,
          goals_by_event: goals_by_event.transform_values(&:freeze).freeze
        }.freeze
      end

      def freeze_experiment(experiment)
        variants = experiment.variants.sort_by { |v| [v.position, v.key] }.map do |v|
          {
            id: v.id,
            key: v.key,
            weight: v.weight,
            position: v.position,
            implementation_key: v.implementation_key,
            is_control: v.is_control
          }.freeze
        end

        {
          id: experiment.id,
          key: experiment.key,
          status: experiment.status,
          target_key: experiment.target_key,
          assignment_scope: experiment.assignment_scope,
          traffic_percentage: experiment.traffic_percentage,
          allocation_seed: experiment.allocation_seed,
          allocation_version: experiment.allocation_version,
          scope_root_recording_id: experiment.scope_root_recording_id,
          variants: variants.freeze
        }.freeze
      end
    end
  end
end
