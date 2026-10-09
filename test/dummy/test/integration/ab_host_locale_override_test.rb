# frozen_string_literal: true

require "test_helper"

class AbHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @load_path_before = I18n.load_path.dup
    @user = User.find_or_create_by!(email: "admin@admin.com") do |u|
      u.password = "Password"
      u.password_confirmation = "Password"
    end
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    Current.actor = @user
    @admin_recording = RecordingStudio.root_recording_for(@admin_root)
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: @admin_recording,
      actor: @user
    )
    raise result.error if result.failure?

    sign_in @user
    switch_to_admin_root!
  end

  teardown do
    Current.actor = nil
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  def switch_to_admin_root!
    get "/recording_studio_root_switchable/v1/root_switch", params: { scope: "all_workspaces" }
    assert_response :success

    patch "/recording_studio_root_switchable/v1/root_switch",
          params: {
            scope: "all_workspaces",
            root_switch: {
              root_recording_id: @admin_recording.id,
              scope: "all_workspaces"
            }
          }
    assert_response :redirect
    follow_redirect!
  end

  test "host locale override for recording_studio.ab_tests wins on real admin page" do
    host_locale = Rails.root.join("config/locales/en.yml")
    assert File.exist?(host_locale)
    assert_includes File.read(host_locale), "HOST New experiment"

    get "/ab_tests/admin/experiments/new"
    assert_response :success
    assert_includes response.body, "HOST New experiment"
    assert_equal "HOST New experiment",
                 I18n.t("recording_studio.ab_tests.experiments.new.title")
  end
end
