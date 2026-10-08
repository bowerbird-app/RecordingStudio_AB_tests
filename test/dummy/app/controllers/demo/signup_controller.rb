# frozen_string_literal: true

module Demo
  # Host-owned surface that renders the same `:signup_page` partial target used
  # by Demo C. Used because Users v0.15.0 prepends its engine views on the real
  # registrations#new action (see recording_studio_ab_tests_view_paths.rb).
  class SignupController < ApplicationController
    skip_before_action :authenticate_user!

    def show
      @resource = User.new
    end
  end
end
