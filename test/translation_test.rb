# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

# Gem-level proofs that RecordingStudio.t falls back to this gem's English once
# config/locales/en.yml is registered (test_helper mirrors boot registration;
# dummy AbEnglishFallbackTest asserts the real engine boot path).
class TranslationTest < Minitest::Test
  GEM_EN_YML = File.expand_path("../config/locales/en.yml", __dir__)
  GEM_KEYS = {
    "recording_studio.ab_tests.common.cancel" => "Cancel",
    "recording_studio.ab_tests.common.empty" => "—",
    "recording_studio.ab_tests.experiments.new.title" => "New experiment",
    "recording_studio.ab_tests.experiments.new.alert_title" => "Could not save",
    "recording_studio.ab_tests.flashes.variant_added" => "Variant added.",
    "recording_studio.ab_tests.metrics.lift_label" => "not statistically tested"
  }.freeze

  def setup
    @previous_backend = I18n.backend
    @previous_load_path = I18n.load_path.dup
    @previous_locale = I18n.locale
    @previous_locales = I18n.available_locales
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = [GEM_EN_YML]
    I18n.backend.load_translations
    I18n.available_locales = (@previous_locales + %i[en fr de xx]).uniq
    I18n.locale = :en
    RecordingStudio::Translation.reset_shipped_english!
  end

  def teardown
    I18n.locale = @previous_locale if @previous_locale
    I18n.available_locales = @previous_locales if @previous_locales
    I18n.load_path = @previous_load_path if @previous_load_path
    I18n.backend = @previous_backend if @previous_backend
    RecordingStudio::Translation.reset_shipped_english!
  end

  # Must fail if registration is dropped from test_helper / boot. Does not call
  # register_shipped_english or the engine initializer block.
  def test_this_gem_en_yml_path_is_registered_for_shipped_english
    path = File.expand_path(GEM_EN_YML)
    registered = RecordingStudio::Translation.send(:registered_shipped_english_paths)

    assert_includes registered, path
    assert_equal "Cancel", RecordingStudio::Translation.shipped_english.fetch(
      "recording_studio.ab_tests.common.cancel"
    )
  end

  def test_deleted_loaded_english_falls_back_to_this_gem_en_yml_in_en_and_fr
    GEM_KEYS.each_key do |key|
      delete_loaded_translation!(:en, key)
      delete_loaded_translation!(:fr, key)
    end

    GEM_KEYS.each do |key, english|
      refute I18n.exists?(key, :en), "#{key} must be absent from loaded :en"
      I18n.with_locale(:en) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
      I18n.with_locale(:fr) do
        assert_equal english, RecordingStudio.t(key)
        refute_match(/translation missing/i, RecordingStudio.t(key))
      end
    end
  ensure
    I18n.reload!
  end

  def test_missing_locale_falls_back_to_loaded_english_including_host_override
    key = "recording_studio.ab_tests.common.cancel"
    write_loaded_translation!(:en, key, "HOST EN Cancel")

    I18n.with_locale(:de) do
      refute I18n.exists?(key, :de)
      assert_equal "HOST EN Cancel", RecordingStudio.t(key)
    end
  ensure
    I18n.reload!
  end

  def test_copy_helper_routes_through_recording_studio_t
    I18n.with_locale(:de) do
      assert_equal "Cancel", RecordingStudioAbTests::Copy.t("common.cancel")
      assert_equal "—", RecordingStudioAbTests::Copy.empty
      assert_equal "not statistically tested", RecordingStudioAbTests::Copy.lift_label
    end
  end

  private

  def delete_loaded_translation!(locale, full_key)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node.delete(leaf) }
  end

  def write_loaded_translation!(locale, full_key, value)
    mutate_loaded_translation!(locale, full_key) { |node, leaf| node[leaf] = value }
  end

  def mutate_loaded_translation!(locale, full_key)
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
    yield node, leaf if node.is_a?(Hash)
  end
end
