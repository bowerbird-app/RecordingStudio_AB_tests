# frozen_string_literal: true

module RecordingStudioAbTests
  module Admin
    class GoalsController < BaseController
      before_action :set_experiment
      before_action :set_goal, only: %i[update destroy]

      def create
        return unless authorize_resource!(:edit, @experiment)

        goal = @experiment.goals.new(goal_params)
        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :goal_create
          ) do
            goal.save!
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "goals"), notice: "Goal added."
        rescue ActiveRecord::RecordInvalid => e
          redirect_to admin_experiment_path(@experiment, tab: "goals"), alert: e.record.errors.full_messages.to_sentence
        end
      end

      def update
        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :goal_update
          ) do
            @goal.update!(goal_params)
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "goals"), notice: "Goal updated."
        rescue ActiveRecord::RecordInvalid => e
          redirect_to admin_experiment_path(@experiment, tab: "goals"), alert: e.record.errors.full_messages.to_sentence
        end
      end

      def destroy
        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :goal_destroy
          ) do
            @goal.destroy!
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "goals"), notice: "Goal removed."
        rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError => e
          redirect_to admin_experiment_path(@experiment, tab: "goals"), alert: e.message
        end
      end

      private

      def set_experiment
        @experiment = Experiment.find(params[:experiment_id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def set_goal
        @goal = @experiment.goals.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def goal_params
        params.require(:goal).permit(
          :key, :name, :event_key, :is_primary, :attribution_window_hours, :counting_policy
        )
      end
    end
  end
end
