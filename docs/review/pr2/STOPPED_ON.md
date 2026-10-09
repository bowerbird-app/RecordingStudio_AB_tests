# PR2 stopped-on: Users view-path prepend — RESOLVED in Users v0.16.0

## Original conflict (Users v0.15.0)

`RecordingStudioUser::Auth` prepended the gem's `app/views` ahead of the host, so
plan §14 host overrides could not win on `/users/sign_up`.

## Resolution

`RecordingStudio_users` **v0.16.0** (tag `v0.16.0` @ `6ceb672`) puts host
`app/views` first on auth screens. PR4 pins that tag and runs Demo C on the real
`/users/sign_up` surface via
`app/views/recording_studio_user/auth/registrations/new.html.erb`.

The temporary `/demo/signup` host route was removed.
