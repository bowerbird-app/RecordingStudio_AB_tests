# frozen_string_literal: true

module RecordingStudioAbTests
  module Admin
    class BaseController < ApplicationController
      include RecordingStudioAdmin::AdminActionAuditing if defined?(RecordingStudioAdmin::AdminActionAuditing)

      before_action :require_admin_actor!
      before_action :authorize_admin_actor!

      layout "recording_studio_ab_tests/admin"

      helper_method :recording_studio_admin_context, :current_admin_actor

      private

      def require_admin_actor!
        return if current_admin_actor.present?

        head :unauthorized
      end

      def authorize_admin_actor!
        return if performed?
        return head :forbidden unless defined?(RecordingStudioAdmin)

        RecordingStudioAdmin::Authorization.authorize!(
          recording_studio_admin_context,
          recording: admin_access_recording
        )
      rescue RecordingStudioAdmin::AuthorizationFailed
        head :forbidden
      end

      def recording_studio_admin_context
        @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
          params: params.to_unsafe_h,
          current_actor: current_admin_actor,
          controller: self,
          routes: self,
          view_context: view_context
        )
      end

      def admin_access_recording
        resolver = RecordingStudioAdmin.configuration.access_recording_resolver
        resolver&.call(recording_studio_admin_context)
      end

      def current_admin_actor
        if defined?(RecordingStudioAdmin)
          method_name = RecordingStudioAdmin.configuration.current_actor_method
          return send(method_name) if method_name && respond_to?(method_name, true)
        end

        return Current.actor if defined?(Current) && Current.respond_to?(:actor)

        try(:current_user)
      end

      def authorize_resource_action!(resource_key, action_key, record)
        RecordingStudioAdmin.authorize_resource!(
          key: resource_key,
          action: action_key,
          context: recording_studio_admin_context,
          record: record
        )
      rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
        head :forbidden
        nil
      end

      def authorize_resource!(action_key, record)
        authorize_resource_action!("ab_tests_experiments", action_key, record)
      end
    end
  end
end
