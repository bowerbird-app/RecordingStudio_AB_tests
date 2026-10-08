# PR2 stopped-on: Users v0.15.0 view-path prepend

## Conflict

`RecordingStudioUser::Auth::RegistrationsController#prefer_users_signup_extra_fields`
calls `prepend_view_path(Engine.root.join("app/views"))` on **every** request
(including `registrations#new`). That forces the gem's
`recording_studio_user/auth/registrations/new.html.erb` ahead of any host override
at the same path.

Plan §14's host-override pattern therefore **cannot take effect** for the real
`/users/sign_up` surface without a Users change.

## What PR2 ships instead

- Host control/variant partials under `test/dummy/app/views/ab/signup/`
- Host override file kept at the gem path (`render_ab :signup_page`) for when Users stops prepending
- `source_template` digest + `verify_overrides` / `assert_ab_override_current`
- Host demo route `/demo/signup` that renders `render_ab :signup_page` (screenshots + tests)
- Documented in `test/dummy/config/initializers/recording_studio_ab_tests_view_paths.rb` and README

## Forbidden workaround (not taken)

Monkey-patching or `include`-ing into `RecordingStudioUser::Auth::RegistrationsController`
from this gem/dummy would violate the standing rule against touching other gems' controllers.

## Ask for Users

Prefer limiting `prefer_users_signup_extra_fields` to password/`extra_fields` actions,
or provide a documented host hook so §14 overrides can win on `registrations#new`.
