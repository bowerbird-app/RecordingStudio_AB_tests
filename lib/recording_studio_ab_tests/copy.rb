# frozen_string_literal: true

module RecordingStudioAbTests
  # Locale lookups for AB Tests user-facing copy. Relative keys resolve under
  # `recording_studio.ab_tests` through {RecordingStudio.t} so a missing
  # active-locale value falls back to loaded English (host overrides included),
  # then the caller's `default:`, then the merged shipped English table
  # (this gem registers its `config/locales/en.yml` at boot).
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
