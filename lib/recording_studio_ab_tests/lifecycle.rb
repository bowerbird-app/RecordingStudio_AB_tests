# frozen_string_literal: true

module RecordingStudioAbTests
  module Lifecycle
    module_function

    TRANSITIONS = {
      "draft" => %w[running],
      "running" => %w[paused completed],
      "paused" => %w[running completed],
      "completed" => %w[archived],
      "archived" => []
    }.freeze

    FROZEN_AFTER_START = %i[
      key target_key assignment_scope allocation_seed allocation_version
    ].freeze

    def start!(experiment, actor: nil)
      validate_start!(experiment)
      transition!(experiment, to: "running", actor: actor) do
        experiment.started_at ||= Time.current
        experiment.paused_at = nil
      end
    end

    def pause!(experiment, actor: nil)
      transition!(experiment, to: "paused", actor: actor) do
        experiment.paused_at = Time.current
      end
    end

    def resume!(experiment, actor: nil)
      transition!(experiment, to: "running", actor: actor) do
        experiment.paused_at = nil
      end
    end

    def complete!(experiment, actor: nil)
      transition!(experiment, to: "completed", actor: actor) do
        experiment.completed_at = Time.current
      end
    end

    def archive!(experiment, actor: nil)
      transition!(experiment, to: "archived", actor: actor) do
        experiment.archived_at = Time.current
      end
    end

    def select_winner!(experiment, variant:, actor: nil)
      _ = actor
      raise LifecycleError, "winner must belong to the experiment" unless experiment.variants.exists?(id: variant.id)

      experiment.update!(winner_variant_id: variant.id)
      ActiveSet.bump!
      true
    end

    def duplicate(experiment)
      copy_key = next_copy_key(experiment.key)
      clone = nil
      ActiveRecord::Base.transaction do
        clone = experiment.dup
        clone.assign_attributes(
          key: copy_key,
          name: "#{experiment.name} (copy)",
          status: "draft",
          allocation_seed: SecureRandom.hex(8),
          winner_variant_id: nil,
          started_at: nil,
          paused_at: nil,
          completed_at: nil,
          archived_at: nil
        )
        clone.save!
        experiment.variants.order(:position, :key).each do |variant|
          clone.variants.create!(
            variant.attributes.slice(
              "key", "name", "implementation_key", "is_control", "weight", "position"
            )
          )
        end
        experiment.goals.each do |goal|
          clone.goals.create!(
            goal.attributes.slice(
              "key", "name", "event_key", "is_primary",
              "attribution_window_hours", "counting_policy"
            )
          )
        end
      end
      ActiveSet.bump!
      clone
    end

    def validate_start!(experiment)
      target = RecordingStudioAbTests.registry.target(experiment.target_key)
      raise LifecycleError, "target is not registered" unless target
      raise LifecycleError, "target is invalid: #{target.error_message}" unless target.valid?

      variants = experiment.variants.to_a
      raise LifecycleError, "exactly one control is required" unless variants.one?(&:is_control)
      raise LifecycleError, "weight sum must be > 0" unless variants.sum(&:weight).positive?

      variants.each do |variant|
        unless target.implementation_keys.include?(variant.implementation_key)
          raise LifecycleError, "unknown implementation_key #{variant.implementation_key}"
        end
      end

      goals = experiment.goals.to_a
      raise LifecycleError, "exactly one primary goal is required" unless goals.one?(&:is_primary)

      goals.each do |goal|
        unless RecordingStudioAbTests.registry.event(goal.event_key)
          raise LifecycleError, "unknown event_key #{goal.event_key}"
        end
      end

      validate_implementations_resolve!(target, variants)
      true
    end

    def validate_implementations_resolve!(target, variants)
      variants.each do |variant|
        next if variant.implementation_key == "control" && %i[view partial].include?(target.type)

        case target.type
        when :view, :partial
          next if variant.implementation_key == "control"
          # Rails falls back to base template when variant file is missing; start-time
          # existence checks require a controller lookup_context and are enforced by
          # host tests / Admin (PR3). Registry registration is the PR1 gate.
        when :component, :service
          class_name = target.class_name_for(variant.is_control? ? "control" : variant.key)
          class_name = target.control if variant.is_control?
          class_name ||= target.class_name_for(variant.key)
          constant = class_name&.safe_constantize
          raise LifecycleError, "missing constant #{class_name}" unless constant

          if target.type == :service && !constant.respond_to?(:call)
            raise LifecycleError, "#{class_name} must respond to .call"
          end
        end
      end
    end

    def transition!(experiment, to:, actor: nil)
      from = experiment.status
      allowed = TRANSITIONS.fetch(from, [])
      raise LifecycleError, "cannot transition from #{from} to #{to}" unless allowed.include?(to)

      experiment.status = to
      yield if block_given?
      experiment.created_by = actor if actor && experiment.created_by.nil? && experiment.respond_to?(:created_by=)
      experiment.save!
      ActiveSet.bump!
      true
    rescue ActiveRecord::RecordInvalid => e
      raise LifecycleError, e.message
    end

    def next_copy_key(key)
      n = 1
      loop do
        candidate = "#{key}_copy_#{n}"
        return candidate unless RecordingStudioAbTests::Experiment.exists?(key: candidate)

        n += 1
      end
    end
  end
end
