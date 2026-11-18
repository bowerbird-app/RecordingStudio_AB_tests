# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require_relative "../ab_tests_helper"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include AbTestsHelper

  test "sign in page uses the users auth layout and is not squished by the default layout" do
    get new_user_session_path

    assert_response :success
    # Users v0.15 email-first sign-in (Welcome back → Continue with email).
    assert_includes response.body, "Welcome back"
    assert_includes response.body, "Continue with email"
    assert_includes response.body, 'data-theme="rounded"'
    assert_includes response.body, "min-h-dvh"
    refute_includes response.body, "data-recording-studio-default-layout"
    refute_includes response.body, "mt-28"
    refute_includes response.body, "fixed inset-0"
  end

  test "password sign-in redirects home" do
    user = User.find_or_create_by!(email: "password-sign-in@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    confirm_user!(user)

    post "/users/sign_in/password", params: {
      user: { email: user.email, password: "Password123!" }
    }

    assert_redirected_to root_path
  end

  test "home page renders the root switch dropdown trigger" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    confirm_user!(user)

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
    grant_owner!(user, root_recording)

    get root_path

    assert_response :success
    assert_includes response.body, workspace.name
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
  end

  test "root switch page renders with the host default layout" do
    user = User.find_or_create_by!(email: "root-switch-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    confirm_user!(user)

    sign_in user

    workspace = Workspace.create!(name: "Switch Page Workspace")
    root_recording = RecordingStudio.create_root_recording!(workspace, actor: user)
    grant_owner!(user, root_recording)

    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    refute_includes response.body, "flat-pack-sidebar-layout"
  end

  test "switching returns to the current page when it is a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-redirect-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    confirm_user!(user)

    sign_in user

    source_workspace = Workspace.create!(name: "Source Workspace")
    target_workspace = Workspace.create!(name: "Target Workspace")
    target_root_recording = RecordingStudio.create_root_recording!(target_workspace, actor: user)
    source_root_recording = RecordingStudio.create_root_recording!(source_workspace, actor: user)
    grant_owner!(user, source_root_recording)
    grant_owner!(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/docs/install"
      }
    }

    assert_redirected_to "/docs/install"
  end

  test "switching falls back to home when return_to is not a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-fallback-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    confirm_user!(user)

    sign_in user

    source_workspace = Workspace.create!(name: "Fallback Source Workspace")
    target_workspace = Workspace.create!(name: "Fallback Target Workspace")
    target_root_recording = RecordingStudio.create_root_recording!(target_workspace, actor: user)
    source_root_recording = RecordingStudio.create_root_recording!(source_workspace, actor: user)
    grant_owner!(user, source_root_recording)
    grant_owner!(user, target_root_recording)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/not-a-real-route"
      }
    }

    assert_redirected_to "/"
  end

  private

  def grant_owner!(user, recording)
    previous_actor = Current.actor
    Current.actor = user
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user)
    return if result.success?
    return if result.error.to_s.include?("Access already exists")

    raise result.error
  ensure
    Current.actor = previous_actor
  end
end
