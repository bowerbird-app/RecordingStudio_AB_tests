# frozen_string_literal: true

module RecordingStudioAbTests
  module Admin
    class ExperimentsController < BaseController
      before_action :set_experiment, only: %i[
        show edit update start pause resume complete archive duplicate select_winner
      ]

      def index
        mount = defined?(RecordingStudioAdmin) ? RecordingStudioAdmin.configuration.default_mount_path : "/admin"
        redirect_to "#{mount}/screens/ab_tests_experiments"
      end

      def new
        @experiment = Experiment.new(
          status: "draft",
          assignment_scope: "visitor",
          traffic_percentage: 100,
          allocation_version: "sha256-v1"
        )
        @targets = valid_targets
        @events = registered_events
      end

      def create
        @experiment = Experiment.new(experiment_attributes)
        @experiment.status = "draft"
        @experiment.allocation_version = "sha256-v1"
        @experiment.created_by = current_admin_actor if current_admin_actor

        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :create
          ) do
            ActiveRecord::Base.transaction do
              @experiment.save!
              create_variants_from_params!(@experiment)
              create_primary_goal_from_params!(@experiment)
            end
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment), notice: "Draft experiment created."
        rescue ActiveRecord::RecordInvalid => e
          flash.now[:alert] = e.record.errors.full_messages.to_sentence
          @targets = valid_targets
          @events = registered_events
          render :new, status: :unprocessable_entity
        rescue LifecycleError => e
          flash.now[:alert] = e.message
          @targets = valid_targets
          @events = registered_events
          render :new, status: :unprocessable_entity
        end
      end

      def show
        @metric_rows = RecordingStudioAbTests::Admin.metric_rows_for(@experiment)
        @tab = params[:tab].presence || "configuration"
      end

      def edit
        @targets = valid_targets
        @events = registered_events
      end

      def update
        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :update,
                                                        metadata: { from: @experiment.status }
          ) do
            @experiment.update!(experiment_update_attributes)
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment), notice: "Experiment updated."
        rescue ActiveRecord::RecordInvalid, LifecycleError => e
          flash.now[:alert] = e.message
          @targets = valid_targets
          @events = registered_events
          render :edit, status: :unprocessable_entity
        end
      end

      def start
        lifecycle_action!(:start) { Lifecycle.start!(@experiment, actor: current_admin_actor) }
      end

      def pause
        lifecycle_action!(:pause) { Lifecycle.pause!(@experiment, actor: current_admin_actor) }
      end

      def resume
        lifecycle_action!(:resume) { Lifecycle.resume!(@experiment, actor: current_admin_actor) }
      end

      def complete
        lifecycle_action!(:complete) { Lifecycle.complete!(@experiment, actor: current_admin_actor) }
      end

      def archive
        lifecycle_action!(:archive) { Lifecycle.archive!(@experiment, actor: current_admin_actor) }
      end

      def duplicate
        return unless authorize_resource!(:duplicate, @experiment)

        clone = nil
        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :duplicate, @experiment, audit_action: :duplicate
          ) do
            clone = Lifecycle.duplicate(@experiment)
            true
          end
          redirect_to admin_experiment_path(clone), notice: "Experiment duplicated as draft."
        rescue LifecycleError => e
          redirect_to admin_experiment_path(@experiment), alert: e.message
        end
      end

      def select_winner
        return unless authorize_resource!(:select_winner, @experiment)

        variant = @experiment.variants.find(params.require(:variant_id))
        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :select_winner, @experiment, audit_action: :select_winner,
                                                                 metadata: { variant_id: variant.id }
          ) do
            Lifecycle.select_winner!(@experiment, variant: variant, actor: current_admin_actor)
          end
          redirect_to admin_experiment_path(@experiment), notice: "Winner selected."
        rescue LifecycleError, ActiveRecord::RecordNotFound => e
          redirect_to admin_experiment_path(@experiment), alert: e.message
        end
      end

      private

      def set_experiment
        @experiment = Experiment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def lifecycle_action!(action_key, &)
        return unless authorize_resource!(action_key, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", action_key, @experiment, audit_action: action_key,
                                                             metadata: { from: @experiment.status }, &
          )
          redirect_to admin_experiment_path(@experiment), notice: "Experiment #{action_key}."
        rescue LifecycleError => e
          redirect_to admin_experiment_path(@experiment), alert: e.message
        end
      end

      def experiment_attributes
        params.require(:experiment).permit(
          :name, :description, :key, :target_key, :assignment_scope, :traffic_percentage
        )
      end

      def experiment_update_attributes
        allowed = %i[name description traffic_percentage]
        allowed += %i[key target_key assignment_scope] if @experiment.draft?
        params.require(:experiment).permit(*allowed)
      end

      def create_variants_from_params!(experiment)
        target = RecordingStudioAbTests.registry.target(experiment.target_key)
        raise LifecycleError, "target is not registered" unless target

        selected = Array(params.dig(:experiment, :variant_keys)).map(&:to_s).uniq
        selected &= target.implementation_keys
        selected = ["control"] if selected.empty?
        selected |= ["control"]

        weights = params.dig(:experiment, :variant_weights) || {}
        selected.each_with_index do |impl_key, index|
          weight = weights[impl_key].presence || weights[impl_key.to_sym].presence || 50
          is_control = impl_key == "control"
          key = is_control ? "control" : impl_key
          experiment.variants.create!(
            key: key,
            name: key.to_s.humanize,
            implementation_key: impl_key,
            is_control: is_control,
            weight: weight.to_i,
            position: index
          )
        end
      end

      def create_primary_goal_from_params!(experiment)
        event_key = params.dig(:experiment, :primary_event_key).presence
        raise LifecycleError, "primary goal event is required" if event_key.blank?

        experiment.goals.create!(
          key: "primary",
          name: "Primary",
          event_key: event_key,
          is_primary: true,
          attribution_window_hours: (params.dig(:experiment, :attribution_window_hours).presence || 168).to_i,
          counting_policy: params.dig(:experiment, :counting_policy).presence || "once_per_participant"
        )
      end

      def valid_targets
        RecordingStudioAbTests.registry.targets.values.select(&:valid?)
      end

      def registered_events
        RecordingStudioAbTests.registry.events.values
      end
    end
  end
end
