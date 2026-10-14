# frozen_string_literal: true

module RecordingStudioAbTests
  # Locale lookups for this gem's `recording_studio.ab_tests.*` copy only.
  # Relative keys resolve through {RecordingStudio.t}. Host or other-namespace
  # keys stay on `I18n.t` with their existing `default:`. Missing active-locale
  # values fall back to loaded English (host overrides included), then the
  # caller's `default:`, then the merged shipped English table (this gem
  # registers its `config/locales/en.yml` at boot).
  module Copy
    PREFIX = "recording_studio.ab_tests"

    module_function

    def t(key, **)
      RecordingStudio.t("#{PREFIX}.#{key}", **)
    end

    def scope_label(scope)
      name = scope.to_s
      t("scopes.#{name}", default: name.humanize)
    end

    def counting_policy_label(policy)
      name = policy.to_s
      t("counting_policies.#{name}", default: name.humanize)
    end

    def lift_label
      t("metrics.lift_label")
    end

    def empty
      t("common.empty")
    end
  end
end
