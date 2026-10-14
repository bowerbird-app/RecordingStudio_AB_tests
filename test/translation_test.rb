# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"
require "action_controller"
require "action_view"
require "active_support/core_ext/string/output_safety"

class TranslationTest < Minitest::Test
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
    I18n.load_path = [File.expand_path("../config/locales/en.yml", __dir__)]
    I18n.backend.load_translations
    I18n.available_locales = (@previous_locales + %i[en fr de xx]).uniq
    I18n.locale = :en
    RecordingStudioAbTests::Translation.reset_shipped_english!
  end

  def teardown
    I18n.locale = @previous_locale if @previous_locale
    I18n.available_locales = @previous_locales if @previous_locales
    I18n.load_path = @previous_load_path if @previous_load_path
    I18n.backend = @previous_backend if @previous_backend
    RecordingStudioAbTests::Translation.reset_shipped_english!
  end

  def test_english_locale_resolves_every_sample_gem_key
    I18n.with_locale(:en) do
      GEM_KEYS.each do |key, english|
        assert_equal english, RecordingStudioAbTests.t(key)
        assert_equal english, RecordingStudioAbTests::Translation.t(key)
      end
    end
  end

  def test_shipped_english_table_matches_gem_en_yml
    RecordingStudioAbTests::Translation.reset_shipped_english!
    en_yml = YAML.safe_load_file(
      File.expand_path("../config/locales/en.yml", __dir__),
      aliases: true
    ).fetch("en").fetch("recording_studio").fetch("ab_tests")

    expected = flatten_locale_keys(en_yml, %w[recording_studio ab_tests])
    table = RecordingStudioAbTests::Translation.shipped_english
    assert_equal expected, table
    assert_predicate table, :frozen?
    table.each_value { |value| assert_predicate value, :frozen? }
    assert_same table, RecordingStudioAbTests::Translation.shipped_english,
                "shipped english must reuse the same object (no per-call file reload)"
  end

  def test_deleted_loaded_english_falls_back_to_shipped_gem_en_yml_text
    GEM_KEYS.each_key do |key|
      delete_loaded_translation!(:en, key)
      delete_loaded_translation!(:fr, key)
    end

    GEM_KEYS.each do |key, english|
      refute I18n.exists?(key, :en), "#{key} must be absent from loaded :en"
      I18n.with_locale(:en) do
        assert_equal english, RecordingStudioAbTests.t(key)
        refute_match(/translation missing/i, RecordingStudioAbTests.t(key))
      end
      I18n.with_locale(:fr) do
        assert_equal english, RecordingStudioAbTests.t(key)
        refute_match(/translation missing/i, RecordingStudioAbTests.t(key))
      end
    end
  ensure
    I18n.reload!
  end

  def test_missing_locale_falls_back_to_loaded_english
    I18n.with_locale(:de) do
      GEM_KEYS.each do |key, english|
        refute I18n.exists?(key, :de), "#{key} must be absent in :de for this test"
        assert_equal english, RecordingStudioAbTests.t(key),
                     "#{key} should fall back to loaded English when :de has no file"
        refute_match(/translation missing/i, RecordingStudioAbTests.t(key))
      end
    end
  end

  def test_does_not_raise_for_missing_locale_when_callers_use_raise_on_missing
    key = "recording_studio.ab_tests.common.cancel"
    I18n.with_locale(:de) do
      assert_raises(I18n::MissingTranslationData) do
        I18n.t(key, locale: :de, raise: true)
      end

      assert_equal "Cancel", RecordingStudioAbTests.t(key)
    end
  end

  def test_parity_matrix_non_gem_keys_match_i18n_t
    I18n.backend.store_translations(:en, {
                                      probe: {
                                        greet: "Hi %{name}",
                                        empty: "",
                                        nil_value: nil,
                                        nest: { a: "A" },
                                        html_key_html: "<b>x</b>",
                                        items: { one: "one item", other: "%{count} items" }
                                      }
                                    })
    I18n.backend.store_translations(:de, { probe: { greet: "Hallo %{name}" } })

    I18n.with_locale(:de) do
      assert_parity("probe.greet", name: "M")
      assert_parity("probe.missing")
      assert_parity("probe.missing", default: "D")
      assert_parity("probe.empty")
      assert_parity("probe.nil_value")
      assert_parity("probe.nest")
      assert_parity("probe.items", count: 1)
      assert_parity("probe.items", count: 5)
      assert_parity(:"probe.greet", name: "M")
      assert_parity(%w[probe.missing probe.greet], name: "M")
      assert_parity("greet", scope: "probe", name: "M")
      assert_raise_parity("probe.missing", raise: true)
      assert_parity("probe.greet", locale: :en, name: "M")
      assert_parity("probe.html_key_html")
    end
  end

  def test_parity_matrix_gem_keys_cover_missing_default_raise_nil_empty_hash_and_related_options
    key = "recording_studio.ab_tests.common.cancel"
    missing = "recording_studio.ab_tests.common.missing_key_for_parity"

    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        ab_tests: {
                                          common: {
                                            nil_value: nil,
                                            empty_value: "",
                                            nest: { a: "A" },
                                            html_key_html: "<i>g</i>",
                                            items: { one: "one", other: "%{count} many" },
                                            greet: "Hi %{name}"
                                          }
                                        }
                                      }
                                    })

    I18n.with_locale(:en) do
      assert_equal I18n.t(key), RecordingStudioAbTests.t(key)
      assert_equal "Cancel", RecordingStudioAbTests.t(key, default: "Ignored when present")
    end

    I18n.with_locale(:de) do
      assert_equal "Cancel", RecordingStudioAbTests.t(key),
                   "missing active locale uses loaded English"
      assert_match(/translation missing/i, I18n.t(key))

      assert_parity(missing)
      assert_parity(missing, default: "D")
      assert_raise_parity(missing, raise: true)

      I18n.backend.store_translations(:de, {
                                        recording_studio: { ab_tests: { common: { cancel: "DE Annuler" } } }
                                      })
      assert_equal "DE Annuler", RecordingStudioAbTests.t(key)
      assert_equal I18n.t(key), RecordingStudioAbTests.t(key),
                   "no English fallback when the active locale has the key"

      assert_parity("recording_studio.ab_tests.common.nil_value")
      assert_equal "", RecordingStudioAbTests.t("recording_studio.ab_tests.common.empty_value")
      assert_match(/translation missing/i, I18n.t("recording_studio.ab_tests.common.empty_value"))

      assert_equal(
        I18n.t("recording_studio.ab_tests.common.nest", locale: :en),
        RecordingStudioAbTests.t("recording_studio.ab_tests.common.nest")
      )
      assert_equal(
        I18n.t("recording_studio.ab_tests.common.items", locale: :en, count: 1),
        RecordingStudioAbTests.t("recording_studio.ab_tests.common.items", count: 1)
      )
      assert_equal(
        I18n.t("recording_studio.ab_tests.common.greet", locale: :en, name: "M"),
        RecordingStudioAbTests.t("recording_studio.ab_tests.common.greet", name: "M")
      )

      assert_equal "DE Annuler", RecordingStudioAbTests.t(:"recording_studio.ab_tests.common.cancel")
      assert_equal(
        ["DE Annuler", "—"],
        RecordingStudioAbTests.t(%w[
                                   recording_studio.ab_tests.common.cancel
                                   recording_studio.ab_tests.common.empty
                                 ])
      )
      assert_equal "DE Annuler", RecordingStudioAbTests.t(:cancel, scope: "recording_studio.ab_tests.common")

      assert_equal(
        "—",
        RecordingStudioAbTests.t(:empty, scope: "recording_studio.ab_tests.common"),
        "scope: gem key missing in :de must fall back to English"
      )

      html = RecordingStudioAbTests.t("recording_studio.ab_tests.common.html_key_html")
      assert_equal "<i>g</i>", html
      assert_predicate html, :html_safe?

      assert_equal "D", RecordingStudioAbTests.t(missing, default: "D")

      I18n.backend.store_translations(:en, {
                                        recording_studio: {
                                          ab_tests: { common: { missing_key_for_parity: "EN" } }
                                        }
                                      })
      assert_equal "EN", RecordingStudioAbTests.t(missing, default: "D")

      error = assert_raises(I18n::MissingTranslationData) do
        RecordingStudioAbTests.t("recording_studio.ab_tests.common.totally_absent", raise: true)
      end
      assert_match(/Translation missing: de\.recording_studio/, error.message)

      assert_equal "Cancel", RecordingStudioAbTests.t(key, locale: :en)
    end
  end

  def test_fallback_order_prefers_loaded_english_then_caller_default_over_shipped_table
    key = "recording_studio.ab_tests.common.cancel"

    write_loaded_translation!(:en, key, "HOST EN Cancel")
    I18n.with_locale(:de) do
      refute I18n.exists?(key, :de)
      assert_equal "HOST EN Cancel", RecordingStudioAbTests.t(key),
                   "host :en override must win over the gem-shipped table"
    end

    delete_loaded_translation!(:en, key)
    delete_loaded_translation!(:fr, key)
    %i[en fr de].each do |locale|
      I18n.with_locale(locale) do
        assert_equal "CALLER", RecordingStudioAbTests.t(key, default: "CALLER"),
                     "caller default: must come before the gem-shipped table in #{locale}"
      end
    end

    %i[en fr de].each do |locale|
      I18n.with_locale(locale) do
        assert_equal "Cancel", RecordingStudioAbTests.t(key),
                     "gem table is used last and matches en.yml in #{locale}"
      end
    end
  ensure
    I18n.reload!
  end

  def test_html_gem_keys_escape_unsafe_interpolation_like_view_t
    I18n.backend.store_translations(:en, {
                                      recording_studio: {
                                        ab_tests: {
                                          probe: {
                                            hi_html: "<b>Hi %{name}</b>",
                                            greet: "Hi %{name}",
                                            items_html: {
                                              one: "<i>1 x</i>",
                                              other: "<i>%{count} xs</i>"
                                            }
                                          }
                                        }
                                      }
                                    })
    view = ActionController::Base.helpers

    I18n.with_locale(:en) do
      value = RecordingStudioAbTests.t("recording_studio.ab_tests.probe.hi_html", name: "<script>")
      assert_equal "<b>Hi &lt;script&gt;</b>", value
      assert_predicate value, :html_safe?
      assert_equal view.t("recording_studio.ab_tests.probe.hi_html", name: "<script>"), value

      plain = RecordingStudioAbTests.t("recording_studio.ab_tests.probe.greet", name: "<s>")
      assert_equal "Hi <s>", plain
      refute_predicate plain, :html_safe?
      assert_equal view.t("recording_studio.ab_tests.probe.greet", name: "<s>"), plain

      safe_arg = "<u>ok</u>".html_safe
      with_safe = RecordingStudioAbTests.t("recording_studio.ab_tests.probe.hi_html", name: safe_arg)
      assert_equal "<b>Hi <u>ok</u></b>", with_safe
      assert_equal view.t("recording_studio.ab_tests.probe.hi_html", name: safe_arg), with_safe

      plural = RecordingStudioAbTests.t("recording_studio.ab_tests.probe.items_html", count: 2)
      assert_equal "<i>2 xs</i>", plural
      assert_predicate plural, :html_safe?
      assert_equal view.t("recording_studio.ab_tests.probe.items_html", count: 2), plural

      singular = RecordingStudioAbTests.t("recording_studio.ab_tests.probe.items_html", count: 1)
      assert_equal "<i>1 x</i>", singular
      assert_predicate singular, :html_safe?
      assert_equal view.t("recording_studio.ab_tests.probe.items_html", count: 1), singular

      missing_html = "recording_studio.ab_tests.probe.missing_key_html"
      reserved = RecordingStudioAbTests.t(missing_html, default: "<b>ok</b>")
      assert_equal "<b>ok</b>", reserved
      refute_predicate reserved, :html_safe?
      assert_equal view.t(missing_html, default: "<b>ok</b>"), reserved

      # Array caller default on a missing _html key stays unsafe.
      array_default = RecordingStudioAbTests.t(missing_html, default: ["<b>arr</b>"])
      assert_equal "<b>arr</b>", array_default
      refute_predicate array_default, :html_safe?
    end
  end

  def test_lazy_keys_pass_through_like_i18n_t
    I18n.with_locale(:en) do
      assert_equal I18n.t(".lazy_key_without_scope"), RecordingStudioAbTests.t(".lazy_key_without_scope")
    end
  end

  def test_nil_key_does_not_raise_inside_gem_key_check
    begin
      expected = I18n.t(nil)
      actual = RecordingStudioAbTests.t(nil)
      if expected.nil?
        assert_nil actual
      else
        assert_equal expected, actual
      end
    rescue StandardError => e
      error = assert_raises(e.class) { RecordingStudioAbTests.t(nil) }
      assert_equal e.message, error.message
    end
  end

  def test_missing_en_yml_yields_empty_shipped_english_table
    RecordingStudioAbTests::Translation.reset_shipped_english!
    translation = RecordingStudioAbTests::Translation
    translation.stub(:shipped_english_path, "/tmp/definitely_missing_ab_tests_en.yml") do
      assert_equal({}, translation.shipped_english)
    end
  ensure
    RecordingStudioAbTests::Translation.reset_shipped_english!
  end

  def test_shipped_english_table_becomes_a_new_object_after_reload_reset
    before = RecordingStudioAbTests::Translation.shipped_english
    RecordingStudioAbTests::Translation.reset_shipped_english!
    after = RecordingStudioAbTests::Translation.shipped_english

    refute_same before, after
    assert_equal before, after
    assert_predicate after, :frozen?
  end

  def test_global_i18n_config_snapshot_is_unchanged_by_helper
    before = i18n_config_snapshot

    RecordingStudioAbTests.t("recording_studio.ab_tests.common.cancel")
    I18n.with_locale(:de) do
      RecordingStudioAbTests.t("recording_studio.ab_tests.common.cancel")
      RecordingStudioAbTests.t("not_a_gem_key")
    end

    assert_equal before, i18n_config_snapshot
  end

  def test_copy_helper_uses_translation_fallback_without_hand_copied_english_defaults
    I18n.with_locale(:de) do
      assert_equal "Cancel", RecordingStudioAbTests::Copy.t("common.cancel")
      assert_equal "—", RecordingStudioAbTests::Copy.empty
      assert_equal "not statistically tested", RecordingStudioAbTests::Copy.lift_label
      assert_equal "Visitor", RecordingStudioAbTests::Copy.scope_label(:visitor)
      assert_equal "Mystery scope", RecordingStudioAbTests::Copy.scope_label(:mystery_scope)
    end
  end

  private

  def assert_parity(key, **options)
    expected = I18n.t(key, **options)
    actual = RecordingStudioAbTests.t(key, **options)
    assert_equal expected, actual, "parity failed for #{key.inspect} options=#{options.inspect}"
    return unless actual.is_a?(String) && key.to_s.match?(/(\b|_|\.)html\z/)

    assert_equal expected.html_safe?, actual.html_safe?
  end

  def assert_raise_parity(key, **options)
    i18n_error = assert_raises(I18n::MissingTranslationData) { I18n.t(key, **options) }
    rs_error = assert_raises(I18n::MissingTranslationData) { RecordingStudioAbTests.t(key, **options) }
    assert_equal i18n_error.message, rs_error.message
  end

  def i18n_config_snapshot
    {
      load_path: I18n.load_path.map { |path| File.expand_path(path) },
      available_locales: Array(I18n.available_locales).map(&:to_sym).sort,
      exception_handler: I18n.exception_handler,
      enforce_available_locales: I18n.enforce_available_locales,
      fallbacks_class: (I18n.fallbacks.class.name if I18n.respond_to?(:fallbacks)),
      fallbacks_de: (I18n.fallbacks[:de].dup if I18n.respond_to?(:fallbacks)),
      fallbacks_fr: (I18n.fallbacks[:fr].dup if I18n.respond_to?(:fallbacks)),
      fallbacks_en: (I18n.fallbacks[:en].dup if I18n.respond_to?(:fallbacks))
    }
  end

  def flatten_locale_keys(node, prefix)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), result|
        result.merge!(flatten_locale_keys(value, prefix + [key.to_s]))
      end
    else
      { prefix.join(".") => node }
    end
  end

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
