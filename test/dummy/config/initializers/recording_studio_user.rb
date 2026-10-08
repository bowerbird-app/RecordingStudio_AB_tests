# frozen_string_literal: true

module Dummy
  # Dummy-only OmniAuth placeholders so Devise callback routes load when the
  # shared master key is missing. Hosts leave `omniauth_providers` empty.
  module OmniauthFallbacks
    PLACEHOLDER = "dev_placeholder"
    GOOGLE = {
      google_oauth2: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      }
    }.freeze
    ALL = GOOGLE.merge(
      microsoft_graph: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      },
      apple: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER,
        team_id: PLACEHOLDER,
        key_id: PLACEHOLDER,
        pem: PLACEHOLDER
      },
      linkedin: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      },
      instagram: {
        client_id: PLACEHOLDER,
        client_secret: PLACEHOLDER
      }
    ).freeze

    module_function

    def providers
      from_credentials = RecordingStudioUser::Omniauth.providers_from_credentials
      return from_credentials if from_credentials.present?

      Rails.env.test? ? ALL : GOOGLE
    end
  end
end

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  config.layout = "application"
  config.require_password_confirmation = false
  config.omniauth_providers = Dummy::OmniauthFallbacks.providers
  config.omniauth_create_account = true
  config.otp_enabled = false
end
