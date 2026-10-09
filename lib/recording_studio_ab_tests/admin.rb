# frozen_string_literal: true

# Soft-registers when RecordingStudioAdmin is present. Require this file only after
# RecordingStudioAdmin is loaded (see Engine to_prepare).

module RecordingStudioAbTests
  module Admin
    module_function

    MetricRow = Metrics::Row

    ReportingRow = Struct.new(
      :id, :name, :key, :status, :target_key, :unique_exposed, :unique_converters,
      :conversion_rate, :relative_lift, :sample_size, :lift_label,
      keyword_init: true
    )

    RegistryRow = Struct.new(
      :id, :kind, :key, :type_or_subject, :detail, :valid, keyword_init: true
    )

    def engine_mount_path
      RecordingStudioAbTests.configuration.mount_path.presence || "/ab_tests"
    end

    def engine_helpers
      RecordingStudioAbTests::Engine.routes.url_helpers
    end

    def admin_experiments_path
      engine_helpers.admin_experiments_path(script_name: engine_mount_path)
    end

    def admin_experiment_path(experiment)
      engine_helpers.admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def edit_admin_experiment_path(experiment)
      engine_helpers.edit_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def new_admin_experiment_path
      engine_helpers.new_admin_experiment_path(script_name: engine_mount_path)
    end

    def start_admin_experiment_path(experiment)
      engine_helpers.start_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def pause_admin_experiment_path(experiment)
      engine_helpers.pause_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def resume_admin_experiment_path(experiment)
      engine_helpers.resume_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def complete_admin_experiment_path(experiment)
      engine_helpers.complete_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def archive_admin_experiment_path(experiment)
      engine_helpers.archive_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def duplicate_admin_experiment_path(experiment)
      engine_helpers.duplicate_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def select_winner_admin_experiment_path(experiment)
      engine_helpers.select_winner_admin_experiment_path(experiment, script_name: engine_mount_path)
    end

    def mask_id(value)
      str = value.to_s
      return "—" if str.blank?

      str[0, 8]
    end

    def transition_allowed?(experiment, action)
      case action.to_sym
      when :start then Lifecycle::TRANSITIONS.fetch(experiment.status, []).include?("running") && experiment.draft?
      when :pause then experiment.running?
      when :resume then experiment.paused?
      when :complete then %w[running paused].include?(experiment.status)
      when :archive then experiment.completed?
      when :duplicate then true
      when :select_winner then !experiment.draft? && !experiment.archived?
      else false
      end
    end

    def primary_goal_for(experiment)
      experiment.goals.find_by(is_primary: true) || experiment.goals.first
    end

    def metric_rows_for(experiment, goal = nil)
      goal ||= primary_goal_for(experiment)
      return [] unless experiment && goal

      Metrics.for_goal(experiment, goal)
    end

    def default_results_experiment
      Experiment.where(status: "running").order(started_at: :desc, created_at: :desc).first ||
        Experiment.where.not(status: "draft").order(created_at: :desc).first
    end

    def experiment_from_context(context)
      raw = context.params[:experiment_id].presence || context.params["experiment_id"].presence
      return Experiment.find_by(id: raw) if raw.present?

      default_results_experiment
    end

    def goal_from_context(context, experiment)
      return nil unless experiment

      raw = context.params[:goal_id].presence || context.params["goal_id"].presence
      return experiment.goals.find_by(id: raw) if raw.present?

      primary_goal_for(experiment)
    end

    def results_rows_for(context)
      experiment = experiment_from_context(context)
      return [] unless experiment

      metric_rows_for(experiment, goal_from_context(context, experiment))
    end

    def reporting_rows
      Experiment.where.not(status: "draft").order(created_at: :desc).filter_map do |experiment|
        goal = primary_goal_for(experiment)
        next unless goal

        rows = Metrics.for_goal(experiment, goal)
        control = rows.find(&:is_control)
        exposed = rows.sum(&:unique_exposed)
        converters = rows.sum(&:unique_converters)
        rate = Metrics.rate_numeric(converters, exposed)
        control_rate = control ? Metrics.rate_numeric(control.unique_converters, control.unique_exposed) : nil

        ReportingRow.new(
          id: experiment.id,
          name: experiment.name,
          key: experiment.key,
          status: experiment.status,
          target_key: experiment.target_key,
          unique_exposed: exposed,
          unique_converters: converters,
          conversion_rate: Metrics.format_rate(rate),
          relative_lift: control ? aggregated_lift(rows, control_rate) : Metrics::ZERO_DISPLAY,
          sample_size: exposed,
          lift_label: Metrics::LIFT_LABEL
        )
      end
    end

    def aggregated_lift(rows, control_rate)
      treatment = rows.reject(&:is_control)
      return Metrics::ZERO_DISPLAY if treatment.empty? || control_rate.nil? || control_rate.zero?

      converters = treatment.sum(&:unique_converters)
      exposed = treatment.sum(&:unique_exposed)
      rate = Metrics.rate_numeric(converters, exposed)
      Metrics.format_lift(rate, control_rate, control: false)
    end

    def registry_rows
      targets = RecordingStudioAbTests.registry.targets.values.map do |target|
        RegistryRow.new(
          id: "target:#{target.key}",
          kind: "target",
          key: target.key.to_s,
          type_or_subject: target.type.to_s,
          detail: target.implementation_keys.join(", "),
          valid: target.valid?
        )
      end
      events = RecordingStudioAbTests.registry.events.values.map do |event|
        RegistryRow.new(
          id: "event:#{event.key}",
          kind: "event",
          key: event.key.to_s,
          type_or_subject: event.subject.to_s,
          detail: "#{event.label} (#{event.source})",
          valid: true
        )
      end
      targets + events
    end

    def exposures_last_7_days_series
      since = 7.days.ago.beginning_of_day
      counts = Exposure.where("first_exposed_at >= ?", since)
                       .group(Arel.sql("DATE(first_exposed_at)"))
                       .count
      (0..6).map do |offset|
        day = (Date.current - (6 - offset))
        { x: day.iso8601, y: counts[day] || counts[day.to_s] || 0 }
      end
    end

    def daily_reporting_series
      since = 14.days.ago.beginning_of_day
      exposure_counts = Exposure.where("first_exposed_at >= ?", since)
                                .group(Arel.sql("DATE(first_exposed_at)"))
                                .count
      conversion_counts = Conversion.where("occurred_at >= ?", since)
                                    .group(Arel.sql("DATE(occurred_at)"))
                                    .count
      days = (0..13).map { |offset| Date.current - (13 - offset) }
      [
        {
          name: "Exposures",
          data: days.map { |day| { x: day.iso8601, y: exposure_counts[day] || exposure_counts[day.to_s] || 0 } }
        },
        {
          name: "Conversions",
          data: days.map { |day| { x: day.iso8601, y: conversion_counts[day] || conversion_counts[day.to_s] || 0 } }
        }
      ]
    end

    def unique_exposures_for(experiment)
      experiment.exposures.select(:assignment_id).distinct.count
    end

    def primary_conversions_for(experiment)
      goal = primary_goal_for(experiment)
      return 0 unless goal

      experiment.conversions.where(goal_id: goal.id).select(:assignment_id).distinct.count
    end

    def primary_rate_for(experiment)
      exposed = unique_exposures_for(experiment)
      return Metrics::ZERO_DISPLAY if exposed.zero?

      Metrics.format_rate(primary_conversions_for(experiment).to_f / exposed)
    end

    def target_type_for(experiment)
      RecordingStudioAbTests.registry.target(experiment.target_key)&.type&.to_s || "—"
    end

    RunningWidget = RecordingStudioAdmin::Widget.new("ab_tests.running") do
      type :number
      title "Running experiments"
      info "Experiments currently in the running status."
      value { Experiment.where(status: "running").count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("ab_tests_experiments") }
    end

    Exposures7dWidget = RecordingStudioAdmin::Widget.new("ab_tests.exposures_7d") do
      type :number
      title "Exposures (7d)"
      info "Unique exposure rows first seen in the last 7 days."
      value { Exposure.where("first_exposed_at >= ?", 7.days.ago).count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("ab_tests_exposures") }
    end

    Conversions7dWidget = RecordingStudioAdmin::Widget.new("ab_tests.conversions_7d") do
      type :number
      title "Conversions (7d)"
      info "Conversion rows in the last 7 days."
      value { Conversion.where("occurred_at >= ?", 7.days.ago).count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("ab_tests_conversions") }
    end

    ExposureTrendWidget = RecordingStudioAdmin::Widget.new("ab_tests.exposure_trend") do
      type :chart
      title "Exposure trend"
      info "Daily exposures over the last 7 days."
      chart_type :line
      series do
        [{ name: "Exposures", data: RecordingStudioAbTests::Admin.exposures_last_7_days_series }]
      end
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("ab_tests_reporting") }
    end

    class AbTestsSection < RecordingStudioAdmin::Section
      key "ab_tests"
      title "A/B Tests"
      subtitle "Experiments, results, assignments, and registry"
      blast_radius :site

      widget "ab_tests.running"
      widget "ab_tests.exposures_7d"
      widget "ab_tests.conversions_7d"
      widget "ab_tests.exposure_trend"

      # Screens are only enabled when linked from an enabled section
      # (RecordingStudioAdmin.screen_enabled? walks section link URLs).
      link :experiments, text: "Experiments", url: ->(context) { context.admin_screen_path("ab_tests_experiments") }
      link :results, text: "Results", url: ->(context) { context.admin_screen_path("ab_tests_results") }
      link :assignments, text: "Assignments", url: ->(context) { context.admin_screen_path("ab_tests_assignments") }
      link :exposures, text: "Exposures", url: ->(context) { context.admin_screen_path("ab_tests_exposures") }
      link :conversions, text: "Conversions", url: ->(context) { context.admin_screen_path("ab_tests_conversions") }
      link :reporting, text: "Reporting", url: ->(context) { context.admin_screen_path("ab_tests_reporting") }
      link :registry, text: "Targets & events", url: ->(context) { context.admin_screen_path("ab_tests_registry") }
      link :new_experiment,
           text: "New experiment",
           url: ->(_context) { RecordingStudioAbTests::Admin.new_admin_experiment_path }
    end

    class ExperimentsScreen < RecordingStudioAdmin::Screen
      key "ab_tests_experiments"
      title "Experiments"
      subtitle "Create, run, and manage A/B experiments"
      blast_radius :site

      query { |_context| Experiment.order(created_at: :desc) }

      filter :date_range, field: :created_at, default: :last_30_days
      filter :status, options: -> { Experiment::STATUSES }, searchable: true
      filter :target_key,
             options: -> { Experiment.distinct.order(:target_key).pluck(:target_key) },
             searchable: true
      filter :key,
             options: -> { Experiment.distinct.order(:key).pluck(:key) },
             searchable: true
      filter_presentation :modal, inline_count: 2

      summary do
        label "Experiments"
        hide_change
        hide_period
      end

      table do
        column :name
        column :key
        column :status
        column :target_key, title: "Target"
        column :target_type, title: "Target type",
                             value: ->(row, _ctx) { RecordingStudioAbTests::Admin.target_type_for(row) }
        column :traffic_percentage, title: "Traffic %"
        column :variants_count, title: "Variants",
                                value: ->(row, _ctx) { row.variants.size }
        column :unique_exposures, title: "Unique exposures",
                                  value: ->(row, _ctx) { RecordingStudioAbTests::Admin.unique_exposures_for(row) }
        column :primary_conversions, title: "Primary conversions",
                                     value: ->(row, _ctx) { RecordingStudioAbTests::Admin.primary_conversions_for(row) }
        column :primary_rate, title: "Primary rate",
                              value: ->(row, _ctx) { RecordingStudioAbTests::Admin.primary_rate_for(row) }
        column :created_at
        action :view,
               text: "View",
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.admin_experiment_path(row) }
        action :edit,
               text: "Edit",
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.edit_admin_experiment_path(row) }
        action :start,
               text: "Start",
               method: :post,
               confirm: "Start this experiment? Allocation fields will freeze.",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :start) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.start_admin_experiment_path(row) }
        action :pause,
               text: "Pause",
               method: :post,
               confirm: "Pause this experiment?",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :pause) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.pause_admin_experiment_path(row) }
        action :resume,
               text: "Resume",
               method: :post,
               confirm: "Resume this experiment?",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :resume) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.resume_admin_experiment_path(row) }
        action :complete,
               text: "Complete",
               method: :post,
               confirm: "Complete this experiment?",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :complete) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.complete_admin_experiment_path(row) }
        action :archive,
               text: "Archive",
               method: :post,
               confirm: "Archive this experiment?",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :archive) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.archive_admin_experiment_path(row) }
        action :duplicate,
               text: "Duplicate",
               method: :post,
               confirm: "Duplicate this experiment as a new draft?",
               visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :duplicate) },
               url: ->(row, _ctx) { RecordingStudioAbTests::Admin.duplicate_admin_experiment_path(row) }
        paginate per_page: 25
        default_sort :created_at, direction: :desc
      end
    end

    class ResultsScreen < RecordingStudioAdmin::Screen
      key "ab_tests_results"
      title "Results"
      subtitle "Per-variant metrics for a selected goal (not statistically tested)"
      blast_radius :site

      query { |context| RecordingStudioAbTests::Admin.results_rows_for(context) }

      filter :experiment_id,
             options: -> { Experiment.order(created_at: :desc).pluck(:id).map(&:to_s) }
      filter :goal_id,
             options: -> { Goal.order(:name).pluck(:id).map(&:to_s) }

      summary do
        label "Variants"
        hide_change
        hide_period
      end

      chart do
        title "Conversion rate by variant"
        type :bar
        series do |context|
          rows = Array(context.query_result&.relation)
          [
            {
              name: "Conversion rate %",
              data: rows.map do |row|
                rate = row.conversion_rate.to_s.delete("%")
                y = rate == Metrics::ZERO_DISPLAY ? 0 : rate.to_f
                { x: row.variant_key, y: y }
              end
            }
          ]
        end
      end

      table do
        column :variant_key, title: "Variant"
        column :variant_name, title: "Name"
        column :assignments
        column :unique_exposed, title: "Unique exposed"
        column :raw_conversions, title: "Raw conversions"
        column :unique_converters, title: "Unique converters"
        column :conversion_rate, title: "Conversion rate"
        column :sample_size, title: "Sample size"
        column :relative_lift, title: "Relative lift"
        column :lift_label, title: "Lift note"
        column :total_value, title: "Total value"
        column :value_per_exposed, title: "Value / exposed"
        paginate per_page: 50
      end
    end

    class AssignmentsScreen < RecordingStudioAdmin::Screen
      key "ab_tests_assignments"
      title "Assignments"
      subtitle "Sticky subject assignments (identifiers masked)"
      blast_radius :site

      query { |_context| Assignment.order(assigned_at: :desc) }

      filter :date_range, field: :assigned_at, default: :last_30_days
      filter :experiment_id,
             options: -> { Experiment.order(:name).pluck(:id).map(&:to_s) },
             searchable: true
      filter :variant_id,
             options: -> { Variant.order(:key).pluck(:id).map(&:to_s) },
             searchable: true
      filter_presentation :modal, inline_count: 2

      summary do
        label "Assignments"
        hide_change
        hide_period
      end

      table do
        column :id, title: "ID", value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.id) }
        column :experiment_id, title: "Experiment",
                               value: ->(row, _ctx) { row.experiment&.key || RecordingStudioAbTests::Admin.mask_id(row.experiment_id) }
        column :variant_id, title: "Variant",
                            value: ->(row, _ctx) { row.variant&.key || "—" }
        column :subject_type, title: "Subject type"
        column :subject_identifier, title: "Subject",
                                    value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.subject_identifier) }
        column :bucket
        column :assigned_at
        paginate per_page: 25
      end
    end

    class ExposuresScreen < RecordingStudioAdmin::Screen
      key "ab_tests_exposures"
      title "Exposures"
      subtitle "First and repeat exposures (identifiers masked)"
      blast_radius :site

      query { |_context| Exposure.order(first_exposed_at: :desc) }

      filter :date_range, field: :first_exposed_at, default: :last_30_days
      filter :experiment_id,
             options: -> { Experiment.order(:name).pluck(:id).map(&:to_s) },
             searchable: true
      filter :variant_id,
             options: -> { Variant.order(:key).pluck(:id).map(&:to_s) },
             searchable: true
      filter_presentation :modal, inline_count: 2

      summary do
        label "Exposures"
        hide_change
        hide_period
      end

      table do
        column :id, title: "ID", value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.id) }
        column :experiment_id, title: "Experiment",
                               value: ->(row, _ctx) { row.experiment&.key || "—" }
        column :variant_id, title: "Variant", value: ->(row, _ctx) { row.variant&.key || "—" }
        column :target_key, title: "Target"
        column :assignment_id, title: "Assignment",
                               value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.assignment_id) }
        column :exposure_count, title: "Count"
        column :first_exposed_at, title: "First"
        column :last_exposed_at, title: "Last"
        paginate per_page: 25
      end
    end

    class ConversionsScreen < RecordingStudioAdmin::Screen
      key "ab_tests_conversions"
      title "Conversions"
      subtitle "Attributed conversions (identifiers masked)"
      blast_radius :site

      query { |_context| Conversion.order(occurred_at: :desc) }

      filter :date_range, field: :occurred_at, default: :last_30_days
      filter :experiment_id,
             options: -> { Experiment.order(:name).pluck(:id).map(&:to_s) },
             searchable: true
      filter :variant_id,
             options: -> { Variant.order(:key).pluck(:id).map(&:to_s) },
             searchable: true
      filter_presentation :modal, inline_count: 2

      summary do
        label "Conversions"
        hide_change
        hide_period
      end

      table do
        column :id, title: "ID", value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.id) }
        column :experiment_id, title: "Experiment",
                               value: ->(row, _ctx) { row.experiment&.key || "—" }
        column :variant_id, title: "Variant", value: ->(row, _ctx) { row.variant&.key || "—" }
        column :goal_id, title: "Goal", value: ->(row, _ctx) { row.goal&.key || "—" }
        column :source_event_key, title: "Event"
        column :source_event_id, title: "Event id",
                                 value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.source_event_id) }
        column :idempotency_key, title: "Idempotency",
                                 value: ->(row, _ctx) { RecordingStudioAbTests::Admin.mask_id(row.idempotency_key) }
        column :value
        column :occurred_at
        paginate per_page: 25
      end
    end

    class ReportingScreen < RecordingStudioAdmin::Screen
      key "ab_tests_reporting"
      title "Reporting"
      subtitle "Primary-goal metrics for non-draft experiments"
      blast_radius :site

      query { |_context| RecordingStudioAbTests::Admin.reporting_rows }

      summary do
        label "Experiments"
        hide_change
        hide_period
      end

      chart do
        title "Daily exposures and conversions"
        type :line
        # Flatpack defaults both series to near-identical primary opacities; override
        # via ChartDefinition#options (passed through to FlatPack::Chart::Component).
        options({
                  colors: [
                    "color-mix(in oklab, var(--color-primary) 100%, transparent)",
                    "color-mix(in oklab, var(--color-primary) 40%, transparent)"
                  ]
                })
        series { |_context| RecordingStudioAbTests::Admin.daily_reporting_series }
      end

      table do
        column :name
        column :key
        column :status
        column :target_key, title: "Target"
        column :unique_exposed, title: "Unique exposed"
        column :unique_converters, title: "Unique converters"
        column :conversion_rate, title: "Conversion rate"
        # sample_size duplicates unique_exposed; omit so Relative lift / Lift note fit.
        # Admin TableDefinition does not expose FlatPack min_width (no custom CSS).
        column :relative_lift, title: "Relative lift"
        column :lift_label, title: "Lift note"
        paginate per_page: 25
      end
    end

    class RegistryScreen < RecordingStudioAdmin::Screen
      key "ab_tests_registry"
      title "Targets & events"
      subtitle "Host-registered AB targets and conversion events"
      blast_radius :site

      query { |_context| RecordingStudioAbTests::Admin.registry_rows }

      summary do
        label "Registry entries"
        hide_change
        hide_period
      end

      table do
        column :kind, title: "Kind"
        column :key
        column :type_or_subject, title: "Type / subject"
        column :detail, title: "Implementations / label"
        column :valid, title: "Valid"
        paginate per_page: 50
      end
    end

    class ExperimentsResource < RecordingStudioAdmin::Resource
      key "ab_tests_experiments"
      section "ab_tests"
      title "A/B experiments"
      blast_radius :site

      action :view,
             text: "View",
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.admin_experiment_path(row) },
             required_role: :admin
      action :edit,
             text: "Edit",
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.edit_admin_experiment_path(row) },
             required_role: :admin
      action :start,
             text: "Start",
             method: :post,
             required_role: :admin,
             confirm: "Start this experiment?",
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :start) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.start_admin_experiment_path(row) }
      action :pause,
             text: "Pause",
             method: :post,
             required_role: :admin,
             confirm: "Pause this experiment?",
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :pause) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.pause_admin_experiment_path(row) }
      action :resume,
             text: "Resume",
             method: :post,
             required_role: :admin,
             confirm: "Resume this experiment?",
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :resume) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.resume_admin_experiment_path(row) }
      action :complete,
             text: "Complete",
             method: :post,
             required_role: :admin,
             confirm: "Complete this experiment?",
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :complete) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.complete_admin_experiment_path(row) }
      action :archive,
             text: "Archive",
             method: :post,
             required_role: :admin,
             confirm: "Archive this experiment?",
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :archive) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.archive_admin_experiment_path(row) }
      action :duplicate,
             text: "Duplicate",
             method: :post,
             required_role: :admin,
             confirm: "Duplicate this experiment?",
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.duplicate_admin_experiment_path(row) }
      action :select_winner,
             text: "Select winner",
             method: :post,
             required_role: :admin,
             visible_if: ->(row, _ctx) { RecordingStudioAbTests::Admin.transition_allowed?(row, :select_winner) },
             url: ->(row, _ctx) { RecordingStudioAbTests::Admin.select_winner_admin_experiment_path(row) }
    end

    def register!
      return unless defined?(RecordingStudioAdmin)
      return if @registered

      RecordingStudioAdmin.register_widget(RunningWidget)
      RecordingStudioAdmin.register_widget(Exposures7dWidget)
      RecordingStudioAdmin.register_widget(Conversions7dWidget)
      RecordingStudioAdmin.register_widget(ExposureTrendWidget)
      RecordingStudioAdmin.register_section(AbTestsSection)
      RecordingStudioAdmin.register_screen(ExperimentsScreen)
      RecordingStudioAdmin.register_screen(ResultsScreen)
      RecordingStudioAdmin.register_screen(AssignmentsScreen)
      RecordingStudioAdmin.register_screen(ExposuresScreen)
      RecordingStudioAdmin.register_screen(ConversionsScreen)
      RecordingStudioAdmin.register_screen(ReportingScreen)
      RecordingStudioAdmin.register_screen(RegistryScreen)
      RecordingStudioAdmin.register_resource(ExperimentsResource)
      @registered = true
    end
  end
end
