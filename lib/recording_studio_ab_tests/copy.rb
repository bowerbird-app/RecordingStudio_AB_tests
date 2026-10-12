# frozen_string_literal: true

module RecordingStudioAbTests
  # Rails I18n lookups for AB Tests user-facing copy. Every call passes
  # `default:` English so a host locale without a fallback never shows
  # "translation missing".
  module Copy
    PREFIX = "recording_studio.ab_tests"

    module_function

    def t(key, **options)
      I18n.t("#{PREFIX}.#{key}", **options)
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
      t("metrics.lift_label", default: Metrics::LIFT_LABEL)
    end

    def empty
      t("common.empty", default: "—")
    end
  end
end
