# CDN and public pages (plan §27)

## Excluded from server-side experiments

Pages published through **RecordingStudio_artifacts** (public press centres and embeds served from Cloudflare R2) **never hit Rails**. `RecordingStudioArtifacts.publish(body:, content_type:, source:)` returns a public URL served from object storage / CDN.

Because there is no Rails request, **RecordingStudioAbTests cannot run server-side experiments on Artifacts/R2 pages**. Do not register targets that assume an Artifacts URL will evaluate assignments, exposures, or conversions.

Per-variant artifact publishing and CDN-edge assignment are **out of V1** (documented as future work only).

## Rails responses with running experiments

When a **running** experiment is evaluated during a Rails request, the gem marks the response:

```ruby
response.cache_control[:private] = true
response.cache_control[:no_store] = true
```

This overrides earlier `expires_in public: true` intent so Cloudflare (or any shared cache) must not store personalized experiment HTML.

## Fragment caching (variant-aware)

Use `ab_cache_vary(*target_keys)` and `render_ab(..., cache: { recording:, entry:, policy: })` so fragment keys differ per variant and **never** include visitor or user ids. Prefer `RecordingStudioCache.fetch(..., vary:)` when the Cache gem is present; otherwise Rails `cache([entry, ab_cache_vary(...)])`.
