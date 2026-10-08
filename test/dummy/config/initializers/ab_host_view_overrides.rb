# frozen_string_literal: true

# RecordingStudioUser::Auth::RegistrationsController prepends the gem view path
# on every action (prefer_users_signup_extra_fields). Demo C needs the host
# override at app/views/recording_studio_user/auth/registrations/new.html.erb to
# win, so prepend the host views after that before_action.
module Dummy
  module PreferHostAbSignupOverride
    extend ActiveSupport::Concern

    included do
      before_action :prefer_host_ab_signup_override
    end

    private

    def prefer_host_ab_signup_override
      prepend_view_path(Rails.root.join("app/views"))
    end
  end
end

Rails.application.config.to_prepare do
  next unless defined?(RecordingStudioUser::Auth::RegistrationsController)

  controller = RecordingStudioUser::Auth::RegistrationsController
  next if controller.included_modules.include?(Dummy::PreferHostAbSignupOverride)

  controller.include Dummy::PreferHostAbSignupOverride
end
