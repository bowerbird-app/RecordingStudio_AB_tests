# frozen_string_literal: true

# Demo C uses the real Users sign-up surface at /users/sign_up.
# RecordingStudio_users v0.16.0 prefers host app/views over the gem's auth
# templates, so the host override at
# app/views/recording_studio_user/auth/registrations/new.html.erb
# (`render_ab :signup_page`) wins. No view-path monkey-patching required.
