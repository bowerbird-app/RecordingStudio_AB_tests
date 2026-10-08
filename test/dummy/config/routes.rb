Rails.application.routes.draw do
  devise_for :users,
             skip: %i[sessions registrations passwords],
             controllers: {
               confirmations: "recording_studio_user/auth/confirmations",
               omniauth_callbacks: "recording_studio_user/omniauth_callbacks"
             }

  recording_studio_user_auth_for :users

  # RecordingStudio engine is data/API-focused and has no browser root route.
  # Keep legacy links working by redirecting the base path to the app home.
  get "/recording_studio", to: redirect("/"), as: nil
  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioRootSwitchable::Engine, at: "/recording_studio_root_switchable"
  mount RecordingStudioUser::Engine => RecordingStudioUser.config.mount_path, as: :recording_studio_users
  mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
  mount RecordingStudioAbTests::Engine, at: "/ab_tests"

  namespace :demo do
    get "pricing", to: "pricing#show", as: :pricing
    post "pricing", to: "pricing#create"
    get "hero", to: "hero#show", as: :hero
    get "signup", to: "signup#show", as: :signup
    get "presskit", to: "presskit#show", as: :presskit
    post "presskit", to: "presskit#create"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  get "docs/install", to: "docs#install", as: :docs_install
  get "docs/config", to: "docs#configuration", as: :docs_config
  get "docs/recordable_types", to: "docs#recordable_types", as: :docs_recordable_types
  get "docs/recordings_tree", to: "docs#recordings_tree", as: :docs_recordings_tree
  get "docs/gem_views", to: "docs#gem_views", as: :docs_gem_views
  get "docs/methods", to: "docs#methods", as: :docs_methods

  root "home#index"
end
