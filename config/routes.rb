# frozen_string_literal: true

RecordingStudioAbTests::Engine.routes.draw do
  namespace :admin do
    resources :experiments, only: %i[index new create show edit update] do
      member do
        post :start
        post :pause
        post :resume
        post :complete
        post :archive
        post :duplicate
        post :select_winner
      end
      resources :variants, only: %i[create update destroy]
      resources :goals, only: %i[create update destroy]
    end
  end
end
