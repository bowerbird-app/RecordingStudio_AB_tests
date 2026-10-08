# frozen_string_literal: true

RecordingStudioAbTests.configure do |config|
  config.enabled = true
  config.exposure_mode = Rails.env.test? ? :inline : :async
  config.raise_errors = Rails.env.local? || Rails.env.test?
  config.allow_force_param = Rails.env.local?
  config.subscribe_to_user_registration = true
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

  # Demo C: gem-owned sign-up page override (plan §14). Digest of
  # recording_studio_user v0.15.0 registrations/new.html.erb.
  signup_path = "recording_studio_user/auth/registrations/new.html.erb"
  signup_digest = "f844930af9cae292428cd333547320c802a3fee5eba0ce78d18056223ca3a52b"
  RecordingStudioAbTests.register_target :signup_page,
    type: :partial,
    label: "Sign-up page body",
    partial: "ab/signup/body",
    variants: { b: { rails_variant: :ab_signup_b } },
    source_template: {
      engine: "RecordingStudioUser::Engine",
      path: signup_path,
      digest: signup_digest
    }

  RecordingStudioAbTests.register_target :presskit_cta,
    type: :partial,
    label: "Press kit CTA",
    partial: "demo/presskit/cta",
    variants: { b: { rails_variant: :ab_presskit_b } }

  # Demo F: service adapter via RecordingStudioAbTests.execute
  RecordingStudioAbTests.register_target :quote_strategy,
    type: :service,
    label: "Quote strategy",
    control: "Quote::Standard",
    variants: { b: "Quote::Alternative" }

  # Demo G: workflow — one sticky assignment across steps (not a separate type)
  RecordingStudioAbTests.register_target :onboarding_flow,
    type: :partial,
    label: "Onboarding flow",
    partial: "onboarding/steps/details",
    variants: { b: { rails_variant: :ab_flow_b } }

  # Demo H: cached fragment with ab_cache_vary
  RecordingStudioAbTests.register_target :cached_hero,
    type: :partial,
    label: "Cached hero",
    partial: "demo/cached/hero",
    variants: { b: { rails_variant: :ab_cached_b } }

  RecordingStudioAbTests.register_event :demo_signup,
    label: "Demo signup",
    subject: :user,
    source: :host

  RecordingStudioAbTests.register_event :presskit_created,
    label: "Press kit created",
    description: "Demo D host track_event conversion path",
    subject: :user,
    value: false,
    source: :host
end
