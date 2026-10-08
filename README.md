# RecordingStudioAbTests

Server-side A/B testing for Recording Studio hosts. Sticky assignment, exposures,
event-driven conversions, Admin screens, service targets, and variant-aware
fragment caching.

Built on RecordingStudio (dummy GitHub tag `v4.3.0`), FlatPack (`v0.1.198`),
Accessible (`v0.11.2`), Users (`v0.15.0`), Admin (`v2.0.5`), Root Switchable
(`v0.5.1`), and optionally RecordingStudioCache (`v0.4.0`, public).

**Version:** `0.3.0`

## Install

```ruby
# Host Gemfile
gem "recording_studio_ab_tests", github: "bowerbird-app/RecordingStudio_AB_tests", tag: "v0.3.0"
# Optional — enables RecordingStudioCache-backed render_ab cache:
gem "recording_studio_cache", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.4.0"
```

```bash
bundle install
bin/rails g recording_studio_ab_tests:install
bin/rails g recording_studio_ab_tests:migrations
bin/rails db:migrate
```

Installation creates no experiments. With zero running experiments the gem does no work.

## Registration

Register inside `Rails.application.config.to_prepare` so development reloads re-register.
Class names are **strings**, constantized at use.

```ruby
Rails.application.config.to_prepare do
  RecordingStudioAbTests.register_target :pricing_page, type: :view,
    template: "pricing/show",
    variants: { b: { rails_variant: :ab_pricing_b } }

  RecordingStudioAbTests.register_target :signup_page, type: :partial,
    partial: "ab/signup/body",
    variants: { b: { rails_variant: :ab_signup_b } }

  RecordingStudioAbTests.register_target :hero_component, type: :component,
    control: "Demo::HeroControlComponent",
    variants: { b: "Demo::HeroVariantBComponent" }

  RecordingStudioAbTests.register_target :quote_strategy, type: :service,
    control: "Quote::Standard",
    variants: { b: "Quote::Alternative" }

  RecordingStudioAbTests.register_event :presskit_created,
    label: "Press kit created", subject: :user, value: false, source: :host
end
```

Unknown targets raise `UnknownTarget`. Invalid registrations raise in development/test.

## Public API (Part K)

```ruby
RecordingStudioAbTests.configure { |c| ... }
RecordingStudioAbTests.register_target(key, type:, **opts)
RecordingStudioAbTests.register_event(key, label:, subject:, **opts)

render_ab(target_key, **opts)          # view helper (partial/component) and controller (view)
ab_variant(target_key, expose: false)  # :control or variant key; peek never assigns
ab_cache_vary(*target_keys)            # Hash for Cache vary: / Rails cache keys
RecordingStudioAbTests.execute(target_key, subject: nil, **kwargs)

RecordingStudioAbTests.expose(target_key, subject: nil)
RecordingStudioAbTests.track_event(event_key, subject:, event_id: nil, value: nil, occurred_at: Time.current, metadata: {})
RecordingStudioAbTests.link_identity(visitor_id:, user:, source:)
RecordingStudioAbTests.current_visitor_id
```

Conversion recording is internal. No other public methods.

## Override pattern (gem-owned pages)

Host `app/views` take precedence. Override the gem template at the **same path** and call `render_ab` inside:

```text
app/views/.../registrations/new.html.erb   # <%= render_ab :signup_page %>
app/views/ab/signup/_body.html.erb         # control (verbatim gem copy)
app/views/ab/signup/_body.html+ab_signup_b.erb
```

Pin `source_template: { engine:, path:, digest: }` and run
`bin/rails recording_studio_ab_tests:verify_overrides` to catch gem-template drift.

> Note: Users `v0.15.0` prepends its engine views on `registrations#new`, so the
> host override cannot win without a Users change. The dummy uses `/demo/signup`.

## Identity and linking

- Scopes: `visitor` (signed cookie), `user`, `root_recording`.
- Anonymous sticky via signed cookie; authenticated always DB (cross-device).
- `link_identity` / in-request linking promote visitor → user; user row wins.
- **Jobs caveat:** job context gets **no** auto-link. Pass `subject:` (or
  `visitor_id:` where applicable) explicitly for out-of-request `execute` /
  `expose` / `track_event`.

## Prefetch / bots / consent

Eligibility serves control (no new assignment) for bots, blank UA, prefetch
(`Sec-Purpose` / `Purpose` / `X-Sec-Purpose`), HEAD, denied consent, and when
`enabled=false`. Non-GET honours an existing assignment and never creates one.

## Events and conversions

Register events, attach goals in Admin, then `track_event` (or the built-in
`registration.completed.recording_studio_user` subscription). Conversions are
after-commit and idempotent. Assignment ≠ exposure.

## Admin enablement

Soft-registers when `RecordingStudioAdmin` is loaded. Host `AdminRoot` must
include `section :ab_tests`. See Admin docs / dummy `AdminRoot` for the pattern.

## Caching rules

```erb
<%= render_ab :cached_hero,
      cache: { recording: rec, entry: :cached_hero, policy: :default } %>
```

- `ab_cache_vary(:t)` → `{ "ab.t" => "b" }`; resolves **and exposes** before lookup.
- With RecordingStudioCache: `fetch(recording, entry, vary: ab_cache_vary(:t), policy:)`.
- Without: Rails `cache([entry, ab_cache_vary(:t)])`.
- **Never** put visitor or user ids in cache keys.
- **Never** wrap `render_ab` in a cache block that omits `ab_cache_vary` for that target.
- Running-experiment responses are marked `private` + `no_store`.

## CDN / Artifacts exclusion

Pages published through RecordingStudio_artifacts (Cloudflare R2) never hit Rails.
**Server-side experiments cannot run there.** See [`docs/cdn_and_public_pages.md`](docs/cdn_and_public_pages.md).

## Failure policy

AB infrastructure failures (DB/cache/config) → log, instrument
`resolution_error.recording_studio_ab_tests`, serve **control**. Errors inside
host implementations (variant template/component/service) are **not** rescued.

## Benchmarks

```bash
cd test/dummy
bin/rails recording_studio_ab_tests:benchmark
# → tmp/ab_benchmark.md
```

Not a CI gate. Numbers are environment-specific.

## Dummy demos

| Demo | Path | Target |
| --- | --- | --- |
| A View | `/demo/pricing` | `:pricing_page` |
| B Component | `/demo/hero` | `:hero_component` |
| C Signup | `/demo/signup` | `:signup_page` |
| D Press kit | `/demo/presskit` | `:presskit_cta` + `track_event` |
| E Admin | `/admin` → A/B Tests | lifecycle + reporting |
| F Service | `/demo/quote` | `execute(:quote_strategy)` |
| G Workflow | `/demo/flow/1..3` | `:onboarding_flow` (sticky) |
| H Cached | `/demo/cached` | `render_ab cache:` |

Force a variant in local/test with `?ab_force=b` when `allow_force_param` is set.

### Quick start (Cloud / Codespaces)

Open port 3000, sign in at `/users/sign_in` (`admin@admin.com` / `Password`).

```bash
cd test/dummy && bin/rails db:setup && bin/dev
```

## Exclusions (V1)

No client-side SDK, no CDN-edge assignment, no per-variant Artifacts publishing,
no multi-armed bandits, no automatic winner deployment, no statistical significance
engine, no AB admin UI outside Recording Studio Admin.
