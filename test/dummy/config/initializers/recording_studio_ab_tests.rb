# frozen_string_literal: true

RecordingStudioAbTests.configure do |config|
  config.enabled = true
  config.exposure_mode = Rails.env.test? ? :inline : :async
  config.raise_errors = Rails.env.local? || Rails.env.test?
  config.allow_force_param = Rails.env.local?
end

Rails.application.config.to_prepare do
  RecordingStudioAbTests.register_target :pricing_page,
    type: :view,
    label: "Pricing page",
    template: "pricing/show",
    variants: { b: { rails_variant: :ab_pricing_b } }

  RecordingStudioAbTests.register_target :hero_component,
    type: :component,
    label: "Hero component",
    control: "Demo::HeroControlComponent",
    variants: { b: "Demo::HeroVariantBComponent" }

  RecordingStudioAbTests.register_event :demo_signup,
    label: "Demo signup",
    subject: :user,
    source: :host
end
