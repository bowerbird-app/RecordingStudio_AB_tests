# frozen_string_literal: true

# Sibling gems still declare recording_studio below 6. Widen that requirement
# when Bundler loads gemspecs so this app can resolve 6.3.0.
module WidenRecordingStudioRequirement
  CORE_FLOOR = ">= 6.3.0"
  CORE_VERSION = Gem::Version.new("6.3.0")

  def add_dependency(name, *requirements)
    requirements = [CORE_FLOOR] if name.to_s == "recording_studio" && !accepts_core_floor?(requirements)

    super
  end

  private

  def accepts_core_floor?(requirements)
    return false if requirements.empty?

    Gem::Requirement.new(*requirements.flatten).satisfied_by?(CORE_VERSION)
  rescue ArgumentError
    false
  end
end

unless Gem::Specification.ancestors.include?(WidenRecordingStudioRequirement)
  Gem::Specification.prepend(WidenRecordingStudioRequirement)
end
