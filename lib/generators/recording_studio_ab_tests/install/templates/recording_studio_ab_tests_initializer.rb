# frozen_string_literal: true

RecordingStudioAbTests.configure do |config|
  # Global kill switch — false serves control with zero work.
  # config.enabled = true

  # config.current_user_resolver = ->(controller) { controller.try(:current_user) }
  # config.user_identifier = ->(user) { user.id.to_s }
  # config.current_root_recording_resolver = ->(controller) { controller.try(:current_root_recording) }
  # config.consent_resolver = ->(request) { true }

  # config.exposure_mode = Rails.env.test? ? :inline : :async
  # config.raise_errors = Rails.env.test?
end

Rails.application.config.to_prepare do
  # Register host-owned targets and events here. Re-registration replaces prior entries.
  #
  # RecordingStudioAbTests.register_target :pricing_page, type: :view,
  #   template: "pricing/show",
  #   variants: { b: { rails_variant: :ab_pricing_b } }
  #
  # RecordingStudioAbTests.register_target :quote_strategy, type: :service,
  #   control: "Quote::Standard", variants: { b: "Quote::Alternative" }
  #
  # RecordingStudioAbTests.register_event :presskit_created,
  #   label: "Press kit created", subject: :user, value: false, source: :host
end
