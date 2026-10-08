# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.2.2`)
- Accessible dummy tag `v0.11.2` (bumped from `v0.10.1` for Users)
- Root Switchable dummy tag `v0.5.1`
- FlatPack dummy tag `v0.1.198` (Attachable requires `>= 0.1.198`)
- Users dummy tag `v0.15.0` (PR2)
- Admin dummy tag `v2.0.5` and Attachable `v0.7.4` (Users gemspec soft deps, pinned in dummy only)
- Public RubyGems and GitHub access for dependency installation

## Accessible 0.11 role migration (PR2)

Dummy runs Accessible migration `20261002000012_change_recording_studio_accesses_role_to_string`:

- `recording_studio_accesses.role` changes from **integer** enum (`0/1/2`) to **string** (`view` / `edit` / `admin`)
- Default becomes `"view"`
- Unknown integer values abort the migration

Hosts upgrading Accessible to 0.11.x must run this migration before Users 0.15. Grants go through `bootstrap_owner_access!` / `grant_access` (`RecordingStudio::Access` is readonly).

## Users + Attachable (PR2 dummy)

- `recording_studio_user:migrations` — People, Profile, identities, confirmable columns, `registered_with`, OTP challenges
- `recording_studio_attachable:migrations` — attachments tables + indexes
- `active_storage:install` — blobs/attachments/variants (Attachable uploads)
- Routes: `devise_for :users, skip: %i[sessions registrations passwords], …` + `recording_studio_user_auth_for :users` + mount Users/Attachable engines
- Recordables: `RecordingStudioUser::People`, `RecordingStudioUser::Profile`, `RecordingStudioAttachable::Attachment`
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
