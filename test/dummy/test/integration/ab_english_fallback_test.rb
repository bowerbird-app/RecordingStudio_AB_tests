# frozen_string_literal: true

require "test_helper"

# Behavioral renders through RecordingStudio.t after this gem registers its
# config/locales/en.yml via register_shipped_english.
class AbEnglishFallbackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_ab_tests_host.en.yml")
  GEM_EN_YML = RecordingStudioAbTests::Engine.root.join("config/locales/en.yml")
  HOST_ALERT_TITLE = "HOST Could not save"
  ALERT_KEY = "recording_studio.ab_tests.experiments.new.alert_title"
  TITLE_KEY = "recording_studio.ab_tests.experiments.new.title"
  CANCEL_KEY = "recording_studio.ab_tests.common.cancel"

  setup do
    @previous_locales = I18n.available_locales
    I18n.available_locales = (@previous_locales + %i[en de fr]).uniq
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
    I18n.locale = I18n.default_locale
    I18n.available_locales = @previous_locales if @previous_locales
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

  # Fails if the engine initializer never registers this gem's en.yml.
  # Does not call register_shipped_english or the initializer block.
  test "this gem en.yml path is registered for shipped english at boot" do
    path = File.expand_path(GEM_EN_YML)
    registered = RecordingStudio::Translation.send(:registered_shipped_english_paths)

    assert_includes registered, path
    assert_equal "Cancel", RecordingStudio::Translation.shipped_english.fetch(CANCEL_KEY)
  end

  test "missing locale without translations renders gem english on new experiment page" do
    I18n.with_locale(:de) do
      refute I18n.exists?(TITLE_KEY, :de)

      get "/ab_tests/admin/experiments/new"

      assert_response :success
      assert_includes @response.body, "New experiment"
      assert_includes @response.body, "Cancel"
      refute_ab_tests_translation_missing!(@response.body)
    end
  end

  test "english render matches gem english strings from main" do
    I18n.with_locale(:en) do
      get "/ab_tests/admin/experiments/new"
      assert_response :success
      assert_includes @response.body, "New experiment"
      assert_includes @response.body, "Save draft"
      assert_includes @response.body, "Cancel"
      refute_ab_tests_translation_missing!(@response.body)
      refute_includes @response.body, HOST_ALERT_TITLE
    end
  end

  test "deleted english key on new experiment page shows shipped title without translation missing" do
    delete_loaded_translation!(:en, TITLE_KEY)
    delete_loaded_translation!(:fr, TITLE_KEY)

    refute I18n.exists?(TITLE_KEY, :en)
    refute I18n.exists?(TITLE_KEY, :fr)

    previous_raise = ActionView::Helpers::TranslationHelper.raise_on_missing_translations

    [false, true].each do |raise_on_missing|
      ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_on_missing

      %i[en fr].each do |locale|
        I18n.with_locale(locale) do
          get "/ab_tests/admin/experiments/new"

          assert_response :success
          assert_includes @response.body, "New experiment"
          refute_ab_tests_translation_missing!(@response.body)
        end
      end
    end
  ensure
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = previous_raise
    I18n.reload!
  end

  test "boot-loaded host english override wins on real page via missing-locale fallback" do
    assert File.exist?(BOOT_HOST_LOCALE), "expected boot-loaded host override at #{BOOT_HOST_LOCALE}"
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_ALERT_TITLE
    I18n.t(ALERT_KEY)
    assert_equal HOST_ALERT_TITLE, I18n.t(ALERT_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"
    refute_equal "Could not save", I18n.t(ALERT_KEY),
                 "main gem English must be absent once the host override is loaded"

    I18n.with_locale(:de) do
      refute I18n.exists?(ALERT_KEY, :de)
      assert_equal HOST_ALERT_TITLE, RecordingStudio.t(ALERT_KEY),
                   "fallback comes from the loaded English, host overrides included"

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
      refute_match(/(?<!HOST )Could not save/, response.body)
      refute_ab_tests_translation_missing!(response.body)
    end
  end

  private

  def refute_ab_tests_translation_missing!(body)
    refute_match(
      /translation missing: [a-z]+\.recording_studio\.ab_tests/i,
      body,
      "page must not show missing recording_studio.ab_tests translations"
    )
  end

  def delete_loaded_translation!(locale, full_key)
    I18n.exists?(full_key, locale)
    parts = full_key.split(".").map(&:to_sym)
    leaf = parts.pop
    translations = I18n.backend.send(:translations)
    locale_key = locale.to_sym
    translations[locale_key] = translations[locale_key].dup if translations[locale_key].frozen?

    node = translations[locale_key]
    parts.each do |part|
      break unless node.is_a?(Hash) && node[part].is_a?(Hash)

      node[part] = node[part].dup if node[part].frozen?
      node = node[part]
    end
    node.delete(leaf) if node.is_a?(Hash)
  end
end
