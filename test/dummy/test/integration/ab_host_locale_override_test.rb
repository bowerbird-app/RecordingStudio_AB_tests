# frozen_string_literal: true

require "test_helper"

class AbHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_ALERT_TITLE = "HOST Could not save"
  OVERRIDE_KEY = "recording_studio.ab_tests.experiments.new.alert_title"

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
    host_locale = Rails.root.join("config/locales/recording_studio_ab_tests_host.en.yml")
    assert File.exist?(host_locale)
    assert_includes File.read(host_locale), HOST_ALERT_TITLE
    assert_equal HOST_ALERT_TITLE, I18n.t(OVERRIDE_KEY)

    post "/ab_tests/admin/experiments",
         params: {
           experiment: {
             name: "",
             key: "",
             target_key: "pricing_page",
             assignment_scope: "visitor",
             traffic_percentage: 100,
             primary_event_key: "demo_signup"
           }
         }

    assert_response :unprocessable_entity
    assert_includes response.body, HOST_ALERT_TITLE
    assert_includes response.body, "New experiment"
    refute_includes response.body, "HOST New experiment"
  end
end
