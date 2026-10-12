# frozen_string_literal: true

module RecordingStudioAbTests
  # Per-variant metrics for a selected goal (§34). Aggregate SQL only; Admin frames.
  module Metrics
    module_function

    LIFT_LABEL = "not statistically tested"
    ZERO_DISPLAY = "—"

    Row = Struct.new(
      :variant_id,
      :variant_key,
      :variant_name,
      :is_control,
      :assignments,
      :unique_exposed,
      :raw_conversions,
      :unique_converters,
      :conversion_rate,
      :relative_lift,
      :total_value,
      :value_per_exposed,
      :lift_label,
      :sample_size,
      keyword_init: true
    )

    def for_goal(experiment, goal)
      variants = ordered_variants(experiment)
      return [] if variants.empty? || goal.nil?

      stats = gather_stats(experiment.id, goal.id, variants.map(&:id))
      build_rows(variants, stats)
    end

    def build_rows(variants, stats = {})
      control = variants.find { |variant| control?(variant) }
      control_rate = rate_numeric(
        stats.dig(:unique_converters, control&.id).to_i,
        stats.dig(:unique_exposed, control&.id).to_i
      )

      variants.map do |variant|
        id = variant.id
        exposed = stats.dig(:unique_exposed, id).to_i
        converters = stats.dig(:unique_converters, id).to_i
        rate = rate_numeric(converters, exposed)
        total = stats.dig(:total_values, id)
        total_f = total.nil? ? 0.0 : total.to_f

        Row.new(
          variant_id: id,
          variant_key: variant.key,
          variant_name: variant.name,
          is_control: control?(variant),
          assignments: stats.dig(:assignments, id).to_i,
          unique_exposed: exposed,
          raw_conversions: stats.dig(:raw_conversions, id).to_i,
          unique_converters: converters,
          conversion_rate: format_rate(rate),
          relative_lift: format_lift(rate, control_rate, control: control?(variant)),
          total_value: total_f,
          value_per_exposed: format_value_per_exposed(total_f, exposed),
          lift_label: LIFT_LABEL,
          sample_size: exposed
        )
      end
    end

    def gather_stats(experiment_id, goal_id, variant_ids)
      {
        assignments: Assignment.where(experiment_id: experiment_id, variant_id: variant_ids)
                               .group(:variant_id).count,
        unique_exposed: Exposure.where(experiment_id: experiment_id, variant_id: variant_ids)
                                .group(:variant_id)
                                .distinct
                                .count(:assignment_id),
        raw_conversions: Conversion.where(experiment_id: experiment_id, goal_id: goal_id, variant_id: variant_ids)
                                   .group(:variant_id).count,
        unique_converters: Conversion.where(experiment_id: experiment_id, goal_id: goal_id, variant_id: variant_ids)
                                     .group(:variant_id)
                                     .distinct
                                     .count(:assignment_id),
        total_values: Conversion.where(experiment_id: experiment_id, goal_id: goal_id, variant_id: variant_ids)
                                .group(:variant_id)
                                .sum(:value)
      }
    end

    def ordered_variants(experiment)
      scope = experiment.variants
      scope = scope.order(:position, :key) if scope.respond_to?(:order)
      scope.to_a
    end

    def control?(variant)
      if variant.respond_to?(:is_control?)
        variant.is_control?
      else
        variant.is_control
      end
    end

    def rate_numeric(converters, exposed)
      return nil if exposed.zero?

      converters.to_f / exposed
    end

    def format_rate(rate)
      return ZERO_DISPLAY if rate.nil?

      "#{(rate * 100).round(2)}%"
    end

    def format_lift(rate, control_rate, control:)
      return ZERO_DISPLAY if control
      return ZERO_DISPLAY if rate.nil? || control_rate.nil? || control_rate.zero?

      lift = (rate - control_rate) / control_rate
      "#{(lift * 100).round(2)}%"
    end

    def format_value_per_exposed(total_value, exposed)
      return ZERO_DISPLAY if exposed.zero?

      (total_value.to_f / exposed).round(4)
    end
  end
end
