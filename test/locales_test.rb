# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  EXPECTED_LEAVES = {
    "recording_studio.ab_tests.layout.title" => "A/B Tests admin",
    "recording_studio.ab_tests.common.cancel" => "Cancel",
    "recording_studio.ab_tests.common.remove" => "Remove",
    "recording_studio.ab_tests.common.yes" => "yes",
    "recording_studio.ab_tests.common.empty" => "—",
    "recording_studio.ab_tests.common.key" => "Key",
    "recording_studio.ab_tests.common.name" => "Name",
    "recording_studio.ab_tests.common.weight" => "Weight",
    "recording_studio.ab_tests.common.event" => "Event",
    "recording_studio.ab_tests.common.counting_policy" => "Counting policy",
    "recording_studio.ab_tests.experiments.new.title" => "New experiment",
    "recording_studio.ab_tests.experiments.new.subtitle" => "Save as draft, then start when ready",
    "recording_studio.ab_tests.experiments.new.save" => "Save draft",
    "recording_studio.ab_tests.experiments.new.alert_title" => "Could not save",
    "recording_studio.ab_tests.experiments.edit.title" => "Edit experiment",
    "recording_studio.ab_tests.experiments.edit.page_title" => "Edit %{name}",
    "recording_studio.ab_tests.experiments.edit.subtitle" => "%{key} · %{status}",
    "recording_studio.ab_tests.experiments.edit.save" => "Save changes",
    "recording_studio.ab_tests.experiments.edit.alert_title" => "Could not update",
    "recording_studio.ab_tests.experiments.edit.frozen_title" => "Some fields are frozen",
    "recording_studio.ab_tests.experiments.edit.frozen_description" =>
      "Key, target, and assignment scope cannot change after start.",
    "recording_studio.ab_tests.experiments.show.subtitle" => "%{key} · %{status} · %{target}",
    "recording_studio.ab_tests.experiments.show.action_failed" => "Action failed",
    "recording_studio.ab_tests.experiments.show.start" => "Start",
    "recording_studio.ab_tests.experiments.show.start_confirm" =>
      "Start this experiment? Allocation fields will freeze.",
    "recording_studio.ab_tests.experiments.show.pause" => "Pause",
    "recording_studio.ab_tests.experiments.show.pause_confirm" => "Pause this experiment?",
    "recording_studio.ab_tests.experiments.show.resume" => "Resume",
    "recording_studio.ab_tests.experiments.show.resume_confirm" => "Resume this experiment?",
    "recording_studio.ab_tests.experiments.show.complete" => "Complete",
    "recording_studio.ab_tests.experiments.show.complete_confirm" => "Complete this experiment?",
    "recording_studio.ab_tests.experiments.show.archive" => "Archive",
    "recording_studio.ab_tests.experiments.show.archive_confirm" => "Archive this experiment?",
    "recording_studio.ab_tests.experiments.show.duplicate" => "Duplicate",
    "recording_studio.ab_tests.experiments.show.duplicate_confirm" =>
      "Duplicate this experiment as a new draft?",
    "recording_studio.ab_tests.experiments.show.edit" => "Edit",
    "recording_studio.ab_tests.experiments.show.select_winner" => "Select winner",
    "recording_studio.ab_tests.experiments.show.set_winner" => "Set winner",
    "recording_studio.ab_tests.experiments.show.tabs.configuration" => "Configuration",
    "recording_studio.ab_tests.experiments.show.tabs.variants" => "Variants",
    "recording_studio.ab_tests.experiments.show.tabs.goals" => "Goals",
    "recording_studio.ab_tests.experiments.show.tabs.results" => "Results",
    "recording_studio.ab_tests.experiments.show.fields.name" => "Name:",
    "recording_studio.ab_tests.experiments.show.fields.key" => "Key:",
    "recording_studio.ab_tests.experiments.show.fields.status" => "Status:",
    "recording_studio.ab_tests.experiments.show.fields.target" => "Target:",
    "recording_studio.ab_tests.experiments.show.fields.scope" => "Scope:",
    "recording_studio.ab_tests.experiments.show.fields.traffic" => "Traffic:",
    "recording_studio.ab_tests.experiments.show.fields.description" => "Description:",
    "recording_studio.ab_tests.experiments.show.fields.started" => "Started:",
    "recording_studio.ab_tests.experiments.show.fields.completed" => "Completed:",
    "recording_studio.ab_tests.experiments.show.fields.winner" => "Winner:",
    "recording_studio.ab_tests.experiments.form.name" => "Name",
    "recording_studio.ab_tests.experiments.form.description" => "Description",
    "recording_studio.ab_tests.experiments.form.key" => "Key",
    "recording_studio.ab_tests.experiments.form.key_help" => "Lowercase snake_case identifier",
    "recording_studio.ab_tests.experiments.form.key_frozen" => "Frozen after start",
    "recording_studio.ab_tests.experiments.form.target" => "Target",
    "recording_studio.ab_tests.experiments.form.assignment_scope" => "Assignment scope",
    "recording_studio.ab_tests.experiments.form.traffic_percent" => "Traffic %",
    "recording_studio.ab_tests.experiments.form.variants_heading" => "Variants",
    "recording_studio.ab_tests.experiments.form.variants_hint" =>
      "Control is always included. Select additional implementations and set weights.",
    "recording_studio.ab_tests.experiments.form.implementations" => "%{label} implementations",
    "recording_studio.ab_tests.experiments.form.weight" => "Weight",
    "recording_studio.ab_tests.experiments.form.primary_goal_event" => "Primary goal event",
    "recording_studio.ab_tests.experiments.form.attribution_window_hours" =>
      "Attribution window (hours)",
    "recording_studio.ab_tests.experiments.form.counting_policy" => "Counting policy",
    "recording_studio.ab_tests.experiments.variants.columns.key" => "Key",
    "recording_studio.ab_tests.experiments.variants.columns.name" => "Name",
    "recording_studio.ab_tests.experiments.variants.columns.implementation" => "Implementation",
    "recording_studio.ab_tests.experiments.variants.columns.control" => "Control",
    "recording_studio.ab_tests.experiments.variants.columns.weight" => "Weight",
    "recording_studio.ab_tests.experiments.variants.empty_title" => "No variants",
    "recording_studio.ab_tests.experiments.variants.empty_description" =>
      "Add variants while the experiment is draft.",
    "recording_studio.ab_tests.experiments.variants.add_heading" => "Add variant",
    "recording_studio.ab_tests.experiments.variants.implementation_key" => "Implementation key",
    "recording_studio.ab_tests.experiments.variants.position" => "Position",
    "recording_studio.ab_tests.experiments.variants.add" => "Add variant",
    "recording_studio.ab_tests.experiments.goals.columns.key" => "Key",
    "recording_studio.ab_tests.experiments.goals.columns.name" => "Name",
    "recording_studio.ab_tests.experiments.goals.columns.event" => "Event",
    "recording_studio.ab_tests.experiments.goals.columns.primary" => "Primary",
    "recording_studio.ab_tests.experiments.goals.columns.window_h" => "Window (h)",
    "recording_studio.ab_tests.experiments.goals.columns.counting" => "Counting",
    "recording_studio.ab_tests.experiments.goals.empty_title" => "No goals",
    "recording_studio.ab_tests.experiments.goals.empty_description" =>
      "Add at least one primary goal before starting.",
    "recording_studio.ab_tests.experiments.goals.add_heading" => "Add goal",
    "recording_studio.ab_tests.experiments.goals.window_hours" => "Window (hours)",
    "recording_studio.ab_tests.experiments.goals.counting_policy" => "Counting policy",
    "recording_studio.ab_tests.experiments.goals.primary_goal" => "Primary goal",
    "recording_studio.ab_tests.experiments.goals.add" => "Add goal",
    "recording_studio.ab_tests.experiments.results.intro" =>
      "Sample sizes are shown next to rates. Relative lift is %{lift_label}.",
    "recording_studio.ab_tests.experiments.results.control_suffix" => " (control)",
    "recording_studio.ab_tests.experiments.results.empty_title" => "No metrics yet",
    "recording_studio.ab_tests.experiments.results.empty_description" =>
      "Add a primary goal and collect exposures/conversions to see results.",
    "recording_studio.ab_tests.experiments.results.columns.variant" => "Variant",
    "recording_studio.ab_tests.experiments.results.columns.assignments" => "Assignments",
    "recording_studio.ab_tests.experiments.results.columns.unique_exposed" => "Unique exposed",
    "recording_studio.ab_tests.experiments.results.columns.raw_conversions" => "Raw conversions",
    "recording_studio.ab_tests.experiments.results.columns.unique_converters" =>
      "Unique converters",
    "recording_studio.ab_tests.experiments.results.columns.conversion_rate" => "Conversion rate",
    "recording_studio.ab_tests.experiments.results.columns.sample_size" => "Sample size",
    "recording_studio.ab_tests.experiments.results.columns.relative_lift" => "Relative lift",
    "recording_studio.ab_tests.experiments.results.columns.total_value" => "Total value",
    "recording_studio.ab_tests.scopes.visitor" => "Visitor",
    "recording_studio.ab_tests.scopes.user" => "User",
    "recording_studio.ab_tests.scopes.root_recording" => "Root recording",
    "recording_studio.ab_tests.counting_policies.once_per_participant" => "Once per participant",
    "recording_studio.ab_tests.counting_policies.every_event" => "Every event",
    "recording_studio.ab_tests.metrics.lift_label" => "not statistically tested",
    "recording_studio.ab_tests.flashes.draft_created" => "Draft experiment created.",
    "recording_studio.ab_tests.flashes.experiment_updated" => "Experiment updated.",
    "recording_studio.ab_tests.flashes.experiment_duplicated" => "Experiment duplicated as draft.",
    "recording_studio.ab_tests.flashes.winner_selected" => "Winner selected.",
    "recording_studio.ab_tests.flashes.experiment_action" => "Experiment %{action}.",
    "recording_studio.ab_tests.flashes.experiment_actions.start" => "start",
    "recording_studio.ab_tests.flashes.experiment_actions.pause" => "pause",
    "recording_studio.ab_tests.flashes.experiment_actions.resume" => "resume",
    "recording_studio.ab_tests.flashes.experiment_actions.complete" => "complete",
    "recording_studio.ab_tests.flashes.experiment_actions.archive" => "archive",
    "recording_studio.ab_tests.flashes.variant_added" => "Variant added.",
    "recording_studio.ab_tests.flashes.variant_updated" => "Variant updated.",
    "recording_studio.ab_tests.flashes.variant_removed" => "Variant removed.",
    "recording_studio.ab_tests.flashes.variants_draft_only" => "Variants can only change while draft.",
    "recording_studio.ab_tests.flashes.goal_added" => "Goal added.",
    "recording_studio.ab_tests.flashes.goal_updated" => "Goal updated.",
    "recording_studio.ab_tests.flashes.goal_removed" => "Goal removed.",
    "recording_studio.ab_tests.errors.target_not_registered" => "target is not registered",
    "recording_studio.ab_tests.errors.primary_goal_event_required" => "primary goal event is required",
    "recording_studio.ab_tests.admin.section.title" => "A/B Tests",
    "recording_studio.ab_tests.admin.screens.experiments.title" => "Experiments",
    "recording_studio.ab_tests.admin.widgets.running.title" => "Running experiments",
    "recording_studio.ab_tests.experiments.results.columns.value_per_exposed" => "Value / exposed"
  }.freeze

  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    I18n.backend = I18n::Backend::Simple.new
    I18n.load_path = [File.join(engine_locales_dir, "en.yml")]
    I18n.backend.load_translations
    I18n.locale = :en
  end

  def teardown
    I18n.load_path = @previous_load_path
    I18n.backend = @previous_backend
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_paths_include_config_locales
    existent = RecordingStudioAbTests::Engine.paths["config/locales"].existent.map { |path| File.expand_path(path) }
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))

    assert_includes existent, locale_path
  end

  def test_locales_initializer_is_not_registered
    names = RecordingStudioAbTests::Engine.initializers.map(&:name)
    engine_source = File.read(File.expand_path("../lib/recording_studio_ab_tests/engine.rb", __dir__))

    refute_includes names, "recording_studio_ab_tests.locales"
    refute_includes engine_source, "app.config.i18n.load_path"
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_english_ab_tests_keys_resolve_without_missing_translations
    I18n.with_locale(:en) do
      EXPECTED_LEAVES.each do |full_key, english|
        translation = I18n.t(full_key, default: nil)

        assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
        assert_equal english, I18n.t(full_key, raise: true)
      end
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_ab_tests
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("ab_tests")

    assert tree.key?("layout")
    assert tree.key?("common")
    assert tree.key?("experiments")
    assert tree.key?("flashes")
    assert tree.key?("errors")
    assert tree.key?("admin")
    assert tree["common"].key?("counting_policy")
    assert_equal "Counting policy", tree.dig("common", "counting_policy")
    assert_equal "A/B Tests admin", tree.dig("layout", "title")
    assert_equal "New experiment", tree.dig("experiments", "new", "title")
  end

  def test_interpolated_keys_render_english_with_values
    I18n.with_locale(:en) do
      assert_equal "Edit Pricing",
                   I18n.t("recording_studio.ab_tests.experiments.edit.page_title", name: "Pricing")
      assert_equal "pricing · running · pricing_page",
                   I18n.t(
                     "recording_studio.ab_tests.experiments.show.subtitle",
                     key: "pricing",
                     status: "running",
                     target: "pricing_page"
                   )
      assert_equal "Hero implementations",
                   I18n.t("recording_studio.ab_tests.experiments.form.implementations", label: "Hero")
      assert_equal(
        "Sample sizes are shown next to rates. Relative lift is not statistically tested.",
        I18n.t(
          "recording_studio.ab_tests.experiments.results.intro",
          lift_label: "not statistically tested"
        )
      )
      assert_equal "Experiment pause.",
                   I18n.t(
                     "recording_studio.ab_tests.flashes.experiment_action",
                     action: I18n.t("recording_studio.ab_tests.flashes.experiment_actions.pause")
                   )
    end
  end

  def test_shipped_en_yml_keys_resolve_through_helper_in_en_and_missing_locales
    shipped = shipped_english_keys
    previous_locales = I18n.available_locales
    I18n.available_locales = (previous_locales + %i[en de]).uniq

    shipped.each do |full_key, english|
      next unless english.is_a?(String)

      I18n.with_locale(:en) do
        assert_equal english, RecordingStudio.t(full_key)
      end

      I18n.with_locale(:de) do
        refute I18n.exists?(full_key, :de)
        assert_equal english, RecordingStudio.t(full_key),
                     "#{full_key}: missing-locale fallback must match en.yml"
      end
    end
  ensure
    I18n.available_locales = previous_locales if previous_locales
  end

  def test_every_shipped_string_key_has_a_call_site_or_documented_dynamic_prefix
    shipped = shipped_english_keys
    roots = [
      File.expand_path("../app", __dir__),
      File.expand_path("../lib", __dir__)
    ]
    source = roots.flat_map { |root| Dir[File.join(root, "**", "*.{rb,erb}")] }
                  .map { |path| File.read(path) }
                  .join("\n")

    dynamic_prefixes = %w[
      recording_studio.ab_tests.scopes.
      recording_studio.ab_tests.counting_policies.
      recording_studio.ab_tests.flashes.experiment_actions.
    ]
    # Deprecated key kept for hosts; YAML-anchor sources for Admin confirms.
    allowlisted = %w[
      recording_studio.ab_tests.common.counting_policy
      recording_studio.ab_tests.experiments.show.resume_confirm
      recording_studio.ab_tests.experiments.show.archive_confirm
      recording_studio.ab_tests.experiments.show.duplicate_confirm
    ].to_set

    missing = []
    shipped.each do |full_key, english|
      next unless english.is_a?(String)
      next if allowlisted.include?(full_key)
      next if dynamic_prefixes.any? { |prefix| full_key.start_with?(prefix) }

      rel = full_key.delete_prefix("recording_studio.ab_tests.")
      found = source.include?(full_key) ||
              source.include?(%("#{rel}")) ||
              source.include?(%('#{rel}'))
      missing << full_key unless found
    end

    assert_empty missing,
                 "reverting a translated string to a literal must leave its key unused; missing call sites: #{missing.join(', ')}"
  end

  def test_every_helper_call_site_key_exists_in_en_yml_and_has_no_hand_copied_english_default
    shipped = shipped_english_keys
    roots = [
      File.expand_path("../app", __dir__),
      File.expand_path("../lib", __dir__)
    ]
    files = roots.flat_map { |root| Dir[File.join(root, "**", "*.{rb,erb}")] }
    refute_empty files

    offenders = []
    unknown_keys = []
    admin_path = File.expand_path("../lib/recording_studio_ab_tests/admin.rb", __dir__)

    files.each do |path|
      next if File.expand_path(path) == admin_path

      source = File.read(path)
      each_translation_call_args(source) do |method_name, args|
        keys = extract_ab_tests_keys(method_name, args)
        next if keys.empty? && !args.match?(/recording_studio\.ab_tests/)

        keys.each do |key|
          # Interpolated / dynamic key fragments are not static en.yml leaves.
          next if key.include?("\#{") || key.end_with?(".")

          unknown_keys << "#{path}: #{key}" unless shipped.key?(key)
        end

        next unless args.match?(/\bdefault:\s*/)
        # Dynamic defaults (humanize / to_s) are allowed; hand-copied English is not.
        next if args.match?(/\bdefault:\s*(?:name\.humanize|policy\.humanize|action_key\.to_s)\b/)

        offenders << "#{path}: #{method_name}(... default: ...) args=#{args.gsub(/\s+/, ' ').strip[0, 120]}"
      end
    end

    assert_empty unknown_keys,
                 "RecordingStudio.t keys must exist in en.yml; unknown: #{unknown_keys.join(', ')}"
    assert_empty offenders,
                 "gem recording_studio.ab_tests lookups must not pass hand-copied English default:; found: #{offenders.join(', ')}"
  end

  def test_recording_studio_t_call_sites_only_use_ab_tests_keys
    roots = [
      File.expand_path("../app", __dir__),
      File.expand_path("../lib", __dir__)
    ]
    offenders = []
    copy_path = File.expand_path("../lib/recording_studio_ab_tests/copy.rb", __dir__)

    roots.flat_map { |root| Dir[File.join(root, "**", "*.{rb,erb}")] }.each do |path|
      # Copy.t builds "recording_studio.ab_tests.#{key}" — not a foreign namespace.
      next if File.expand_path(path) == copy_path

      File.read(path).scan(/RecordingStudio\.t\s*\(?\s*["']([^"']+)["']/) do |match|
        key = match[0]
        # Skip interpolated key fragments (e.g. "recording_studio.ab_tests.#{x}").
        next if key.include?("\#{") || key.include?("{")
        next if key.start_with?("recording_studio.ab_tests.")

        offenders << "#{path}: RecordingStudio.t(#{key.inspect})"
      end
    end

    assert_empty offenders,
                 "only recording_studio.ab_tests.* keys may use RecordingStudio.t; " \
                 "host/other-namespace keys stay on I18n.t: #{offenders.join(', ')}"
  end

  def test_scanner_catches_single_quoted_multi_line_i18n_translate_array_and_paren_less_defaults
    samples = {
      lift_label: <<~RUBY,
        RecordingStudio.t("recording_studio.ab_tests.metrics.lift_label", default: Metrics::LIFT_LABEL)
      RUBY
      single_quoted: <<~RUBY,
        RecordingStudio.t('recording_studio.ab_tests.common.cancel', default: 'Cancel')
      RUBY
      multi_line: <<~RUBY,
        RecordingStudio.t(
          "recording_studio.ab_tests.experiments.new.title",
          default: "New experiment"
        )
      RUBY
      i18n_translate: <<~RUBY,
        I18n.translate("recording_studio.ab_tests.common.empty", default: "—")
      RUBY
      array_default: <<~RUBY,
        I18n.t("recording_studio.ab_tests.common.cancel", default: ["Cancel", "Fallback"])
      RUBY
      bare_t: <<~RUBY,
        t("recording_studio.ab_tests.common.cancel", default: "Cancel")
      RUBY
      paren_less: <<~RUBY,
        RecordingStudio.t "recording_studio.ab_tests.common.cancel", default: "Cancel"
      RUBY
      copy_t: <<~RUBY
        Copy.t("common.cancel", default: "Cancel")
      RUBY
    }

    samples.each do |name, source|
      found = false
      each_translation_call_args(source) do |_method_name, args|
        found = true if args.match?(/\bdefault:\s*/)
      end
      assert found, "scanner must catch #{name} default: form"
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def shipped_english_keys
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("ab_tests")
    flatten_locale_keys(tree, %w[recording_studio ab_tests])
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

  def each_translation_call_args(source)
    pattern = /
      (?:RecordingStudio(?:::Translation)?\.t|Copy\.t|I18n\.(?:t|translate)|(?<![\w.:])t)
      (?:
        \s*\(
        |
        \s+(?=["'])
      )
    /mx
    offset = 0
    while (match = pattern.match(source, offset))
      method_name = match[0].sub(/\s*[(]\z/, "").sub(/\s+\z/, "")
      args_start = match.end(0)
      if match[0].include?("(")
        args, args_end = read_balanced_args(source, args_start)
      else
        args, args_end = read_paren_less_args(source, args_start)
      end
      yield method_name, args
      offset = args_end
    end
  end

  def read_paren_less_args(source, start_index)
    index = start_index
    in_single = false
    in_double = false
    escape = false

    while index < source.length
      char = source[index]
      break if !in_single && !in_double && %W[\n ;].include?(char)

      if escape
        escape = false
      elsif char == "\\" && (in_single || in_double)
        escape = true
      elsif char == "'" && !in_double
        in_single = !in_single
      elsif char == '"' && !in_single
        in_double = !in_double
      end
      index += 1
    end

    [source[start_index...index], index]
  end

  def read_balanced_args(source, start_index)
    depth = 1
    index = start_index
    in_single = false
    in_double = false
    escape = false

    while index < source.length && depth.positive?
      char = source[index]

      if escape
        escape = false
      elsif char == "\\" && (in_single || in_double)
        escape = true
      elsif char == "'" && !in_double
        in_single = !in_single
      elsif char == '"' && !in_single
        in_double = !in_double
      elsif !in_single && !in_double
        case char
        when "(" then depth += 1
        when ")" then depth -= 1
        end
      end

      index += 1
    end

    [source[start_index...(index - 1)], index]
  end

  def extract_ab_tests_keys(method_name, args)
    keys = []
    args.scan(/["'](recording_studio\.ab_tests\.[^"']+)["']/) { |match| keys << match[0] }
    if (match = args.match(/%w\[([^\]]+)\]/))
      match[1].split.each do |token|
        keys << token if token.start_with?("recording_studio.ab_tests.")
      end
    end
    if method_name.include?("Copy.t") && (match = args.match(/\A\s*["']([a-z0-9_.]+)["']/i))
      keys << "recording_studio.ab_tests.#{match[1]}"
    end
    keys
  end
end
