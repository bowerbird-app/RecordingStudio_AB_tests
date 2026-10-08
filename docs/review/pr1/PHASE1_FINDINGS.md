# Phase 1 verification findings (PR1)

Confirmed against pinned tags / local bundle unless noted.

## Template / RecordingStudio core

| Check | Result |
| --- | --- |
| `bin/rename_gem recording_studio_ab_tests --dry-run` | OK — maps to `RecordingStudioAbTests` / `recording_studio_ab_tests` |
| Rename verification | Passes after creating `app/views/recording_studio_ab_tests/` (empty; Admin views arrive in PR3) |
| `RecordingStudio.root_recording_for` / `root_recording_id_for` / `root_recording?` | Present in `lib/recording_studio.rb` (core `~> 4.2`, dummy tag `v4.2.2`) |
| `recording_studio_recordings` uuid ids | Confirmed in dummy schema / migrations |
| Core workspace concept | None — Workspace is a host recordable example only |
| `current_root_recording` | Available via `RecordingStudio::RootSwitchable::ControllerSupport` (`alias current_root_recording current_root`); dummy ApplicationController includes Root Switchable |

## RecordingStudio_admin (tag `v2.0.5`; `version.rb` = `2.0.2`)

| Check | Result |
| --- | --- |
| `register_screen/section/resource/widget` | Confirmed in `lib/recording_studio_admin.rb` |
| Registry reload replacement | Same-named definitions replace (onboarding soft-register pattern) |
| `authorize_resource!(key:, context:, action:, record:, audit:, audit_action:)` | Confirmed |
| `AdminActionAuditing#perform_recording_studio_admin_action!` | Private; yields tracker; `false` → `validation_failed` (`admin_action_audit.rb`) |
| `Authorization.authorize!` + `Context.new(params:, current_actor:, controller:, routes:, view_context:)` | Confirmed via onboarding BaseController |
| Free-text search filter | Not found — keep select-based searchable filters (as planned) |
| Chart types `:bar` / `:line`, select `options:` / `searchable:` | Confirmed via onboarding FunnelScreen / RunsScreen |
| Lazy frames + Turbo | Required; deferred to PR3 wiring |

## RecordingStudio_users (tag `v0.15.0`) — PR2 dependency

| Check | Result |
| --- | --- |
| `RegistrationCompleted::EVENT` | `"registration.completed.recording_studio_user"` |
| Payload | `{ user_id:, method: }` with `METHODS = %i[password oauth otp]` |
| Emission | `ActiveRecord.after_all_transactions_commit` then `Notifications.instrument` |
| View path | `recording_studio_user/auth/registrations/new.html.erb` (documented; override pattern in PR2) |
| Accessible resolution | Users gemspec requires `recording_studio_accessible ~> 0.11`; dummy currently pins `v0.10.1`. **Must bump Accessible to `v0.11.0` (or compatible) when adding Users in PR2.** Tag `v0.11.0` exists and was readable. |

## RecordingStudio_cache (tag `v0.4.0`, private) — PR4 dependency

| Check | Result |
| --- | --- |
| Cloud-agent / default `git` / `gh` fetch | **FAIL** — `git ls-remote` → `Repository not found`; `gh api repos/.../RecordingStudio_cache` → 404. Private; this agent’s default credentials cannot clone it. |
| GitHub MCP (org-scoped) | **OK** — can read README, `lib/recording_studio_cache.rb`, Store, KeyBuilder, tag `v0.4.0` |
| `RecordingStudioCache.fetch(recording, entry, policy:, vary:, expires_in:, race_ttl:)` | Confirmed; unknown kwargs raise `ArgumentError` |
| `vary:` | Must be Hash; sorted JSON pairs → SHA256 first 16 hex chars in key |
| Persisted recording | `KeyBuilder.normalize_recording!` requires `id` + `root_recording_id` |
| `invalidate_tree!` | Writes new root-generation UUID (unreachable old keys) |
| CI access | Workflow already sets `BUNDLE_GITHUB__COM: x-access-token:${{ secrets.BOWERBIRD_ORG_CI_TOKEN }}` for dummy `bundle install`. **Cannot verify from this agent that `BOWERBIRD_ORG_CI_TOKEN` can read `RecordingStudio_cache`.** For PR4: confirm the secret’s org/repo access includes that private repo; if not, grant it (or add a dedicated secret and wire it the same way). Do **not** pin the private gem until PR4. |

## RecordingStudio_artifacts (v0.4.0)

| Check | Result |
| --- | --- |
| `publish` / `update` / `unpublish` | Confirmed in README — public R2 URLs, no Rails hit. Docs-only for AB; excluded from V1 server-side experiments. |

## Flatpack (dummy tag `v0.1.196`)

Constructor keywords verified in source:

| Component | Keywords |
| --- | --- |
| `Card` | `style:`, `hover:`, `clickable:`, `href:`, `padding:`, `theme:`, `**system_arguments` |
| `PageHeader` | `title:`, `subtitle:`, `large_subtitle:`, `title_color:`, `subtitle_color:` |
| `Button` | `text:`, `style:`, `size:`, `href:`, `method:`, `target:`, `icon:`, `icon_only:`, `loading:`, `type:` |
| `Badge` | `text:`, `style:`, `size:`, `dot:`, `removable:` |
| `Tabs` | `default_tab:`, `variant:` (`:underline`/`:pills`/`:stacked`), `size:` + `#tab` / `#panel` |
| `Modal` | `id:`, `title:`, `size:`, `body_height_mode:`, `body_height:`, `close_on_backdrop:`, `close_on_escape:` |
| `Alert` | `title:`, `description:`, `style:` (`:info`/`:success`/`:warning`/`:danger`), `dismissible:`, `icon:`, `size:` |
| `FormField` | Internal: `field_id:`, `label:`, `error:`, `help_text:` — hosts use public inputs |
| `Select` | `name:`, `options:`, `value:`, `label:`, `placeholder:`, `disabled:`, `required:`, `searchable:`, `search_mode:`, `multiple:`, `error:`, `help_text:` |
| `Table` / `EmptyState` / `Pagination` / `Chart` / `TextInput` / `TextArea` / `NumberInput` / `Switch` | Present under `app/components/flat_pack/*` at tag; used in PR3 |

## Rails 8.1 / Turbo

| Check | Result |
| --- | --- |
| `render template:/partial:, variants:` | Documented Rails 8.1 PartialRenderer / extract_details — used by adapters |
| `render file:` = RawFile | Do not use for gem-template control (Marco decision: host copy + drift guard) |
| `ActiveRecord.after_all_transactions_commit` | Confirmed (Users RegistrationCompleted) |
| `insert_all(..., unique_by:)` | Used for assignments (`idx_rsab_assignments_subject`) |
| `ActionDispatch::Response#cache_control` | Use hash writers: `response.cache_control[:private] = true` and `[:no_store] = true` (verified). Assigning a raw `Cache-Control` header string does not populate the `#cache_control` hash the same way. PR4 will mark experiment responses private/no-store via the hash API. |
| html_safe via MemoryStore | `ActiveSupport::SafeBuffer` round-trips as html_safe through MemoryStore in this environment. Still mark safe explicitly if a store/backend strips it; do not assume Redis/Solid Cache preserve SafeBuffer. |
| Cookies during view render | Signed cookie jar available via `Current.request` middleware |
| Turbo 8 prefetch | `X-Sec-Purpose: prefetch` — eligibility treats Purpose / Sec-Purpose / X-Sec-Purpose containing `prefetch` as control |

## Decisions applied

- Gem-owned pages: host copy of gem template + `verify_overrides` (PR2), not `render file:` / LookupContext
- Namespace `RecordingStudioAbTests` (no `AB` inflection)
- No Admin / Users / Cache pins in this PR
- Version remains `0.2.3`

## Stopped-on missing extension points

None for PR1 foundation. Cache private-repo CI access is a **PR4 blocker to confirm**, not a PR1 stop.
