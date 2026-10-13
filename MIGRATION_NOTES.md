# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.5.0`)
- Accessible dummy tag `v0.15.0` (i18n wave 2: translation-only; English unchanged). Dummy also carries Accessible 0.14 audience tables (`access_constraints` / `access_rules`) from the intervening minor.
- Root Switchable dummy tag `v0.8.0` (i18n wave 2: translatable page_copy; rendered English unchanged; no host migration). Pins Metrics `v0.2.0` (Root Switchable 0.7+ gemspec `~> 0.2`; GitHub-only)
- FlatPack dummy tag `v0.1.213` (Attachable 0.12+ requires `>= 0.1.213`)
- Users dummy tag `v0.16.0` (PR4; host overrides win on `/users/sign_up`)
- Admin dummy tag `v2.3.0` (Trashable query-only kept lookups; pins Trashable `v0.10.0` `require: false`; Metrics already `v0.2.0`). Attachable `v0.15.0` (i18n wave 2: non-view copy; rendered English unchanged; no host migration; Users gemspec soft deps, pinned in dummy only)
- Public RubyGems and GitHub access for dependency installation

## Accessible 0.11 role migration (PR2)

Dummy runs Accessible migration `20261002000012_change_recording_studio_accesses_role_to_string`:

- `recording_studio_accesses.role` changes from **integer** enum (`0/1/2`) to **string** (`view` / `edit` / `admin`)
- Default becomes `"view"`
- Unknown integer values abort the migration

Hosts upgrading Accessible to 0.11.x must run this migration before Users 0.15. Grants go through `bootstrap_owner_access!` / `grant_access` (`RecordingStudio::Access` is readonly).

## Users + Attachable (PR2 dummy)

- `recording_studio_user:migrations` — People, Profile, identities, confirmable columns, `registered_with`, OTP challenges
- `recording_studio_attachable:migrations` — attachments tables + indexes, plus libraries and placements (Attachable 0.12+)
- `active_storage:install` — blobs/attachments/variants (Attachable uploads)
- Routes: `devise_for :users, skip: %i[sessions registrations passwords], …` + `recording_studio_user_auth_for :users` + mount Users/Attachable engines
- Recordables: `RecordingStudioUser::People`, `RecordingStudioUser::Profile`, `RecordingStudioAttachable::Attachment`, `RecordingStudioAttachable::Library`, `RecordingStudioAttachable::Placement`
- Coexists with the existing Devise `User` model (ProfiledUser is applied by the Users engine)

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
