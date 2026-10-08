# frozen_string_literal: true

module RecordingStudioAbTests
  module Admin
    class VariantsController < BaseController
      before_action :set_experiment
      before_action :set_variant, only: %i[update destroy]
      before_action :require_draft!, only: %i[create update destroy]

      def create
        return unless authorize_resource!(:edit, @experiment)

        variant = @experiment.variants.new(variant_params)
        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :variant_create
          ) do
            variant.save!
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "variants"), notice: "Variant added."
        rescue ActiveRecord::RecordInvalid => e
          redirect_to admin_experiment_path(@experiment, tab: "variants"),
                      alert: e.record.errors.full_messages.to_sentence
        end
      end

      def update
        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :variant_update
          ) do
            @variant.update!(variant_params)
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "variants"), notice: "Variant updated."
        rescue ActiveRecord::RecordInvalid => e
          redirect_to admin_experiment_path(@experiment, tab: "variants"),
                      alert: e.record.errors.full_messages.to_sentence
        end
      end

      def destroy
        return unless authorize_resource!(:edit, @experiment)

        begin
          perform_recording_studio_admin_action!(
            "ab_tests_experiments", :edit, @experiment, audit_action: :variant_destroy
          ) do
            @variant.destroy!
            ActiveSet.bump!
            true
          end
          redirect_to admin_experiment_path(@experiment, tab: "variants"), notice: "Variant removed."
        rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError => e
          redirect_to admin_experiment_path(@experiment, tab: "variants"), alert: e.message
        end
      end

      private

      def set_experiment
        @experiment = Experiment.find(params[:experiment_id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def set_variant
        @variant = @experiment.variants.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      def require_draft!
        return if @experiment&.draft?

        redirect_to admin_experiment_path(@experiment), alert: "Variants can only change while draft."
      end

      def variant_params
        params.require(:variant).permit(:key, :name, :implementation_key, :weight, :position, :is_control)
      end
    end
  end
end
