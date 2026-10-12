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
      unless experiment.variants.exists?(id: variant.id)
        raise LifecycleError, Copy.t("errors.winner_must_belong", default: "winner must belong to the experiment")
      end

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
      raise LifecycleError, Copy.t("errors.target_not_registered", default: "target is not registered") unless target
      unless target.valid?
        raise LifecycleError, Copy.t(
          "errors.target_invalid",
          default: "target is invalid: %{message}",
          message: target.error_message
        )
      end

      variants = experiment.variants.to_a
      unless variants.one?(&:is_control)
        raise LifecycleError, Copy.t("errors.exactly_one_control", default: "exactly one control is required")
      end
      unless variants.sum(&:weight).positive?
        raise LifecycleError, Copy.t("errors.weight_sum_positive", default: "weight sum must be > 0")
      end

      variants.each do |variant|
        unless target.implementation_keys.include?(variant.implementation_key)
          raise LifecycleError, Copy.t(
            "errors.unknown_implementation",
            default: "unknown implementation_key %{key}",
            key: variant.implementation_key
          )
        end
      end

      goals = experiment.goals.to_a
      unless goals.one?(&:is_primary)
        raise LifecycleError, Copy.t(
          "errors.exactly_one_primary_goal",
          default: "exactly one primary goal is required"
        )
      end

      goals.each do |goal|
        unless RecordingStudioAbTests.registry.event(goal.event_key)
          raise LifecycleError, Copy.t(
            "errors.unknown_event",
            default: "unknown event_key %{key}",
            key: goal.event_key
          )
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
          unless constant
            raise LifecycleError, Copy.t(
              "errors.missing_constant",
              default: "missing constant %{name}",
              name: class_name
            )
          end

          if target.type == :service && !constant.respond_to?(:call)
            raise LifecycleError, Copy.t(
              "errors.service_must_call",
              default: "%{name} must respond to .call",
              name: class_name
            )
          end
        end
      end
    end

    def transition!(experiment, to:, actor: nil)
      from = experiment.status
      allowed = TRANSITIONS.fetch(from, [])
      unless allowed.include?(to)
        raise LifecycleError, Copy.t(
          "errors.cannot_transition",
          default: "cannot transition from %{from} to %{to}",
          from: from,
          to: to
        )
      end

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
