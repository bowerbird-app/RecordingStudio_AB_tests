# frozen_string_literal: true

# STOPPED-ON USERS CONFLICT (v0.15.0)
# ------------------------------------
# RecordingStudioUser::Auth::RegistrationsController#prefer_users_signup_extra_fields
# calls `prepend_view_path(Engine.root.join("app/views"))` on every request so
# TnC can win on `_extra_fields`. That also forces the gem's
# `registrations/new.html.erb` ahead of any host override at the same path.
#
# Plan §14's host-override pattern therefore cannot take effect for signup
# without a Users change (or monkey-patching the gem controller — forbidden).
#
# Demo C keeps:
# - host control/variant partials under app/views/ab/signup/
# - source_template digest + verify_overrides / assert_ab_override_current
# - override file at the gem path (ready if Users stops prepending)
# - /demo/signup host route that renders `render_ab :signup_page` for demos/tests
#
# Do not monkey-patch Users from this gem or the dummy.
