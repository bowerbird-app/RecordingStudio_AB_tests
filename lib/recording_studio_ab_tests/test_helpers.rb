# frozen_string_literal: true

require "digest"

module RecordingStudioAbTests
  module TestHelpers
    # Recomputes the digest of a gem template referenced by source_template: and
    # fails when the host override copy is stale (plan §14 drift guard).
    def assert_ab_override_current(target_key)
      target = RecordingStudioAbTests.registry.fetch_target!(target_key)
      source = target.source_template
      flunk("target #{target_key} has no source_template:") unless source

      engine_name = source[:engine] || source["engine"]
      path = source[:path] || source["path"]
      expected = source[:digest] || source["digest"]
      flunk("source_template for #{target_key} is incomplete") if engine_name.blank? || path.blank? || expected.blank?

      engine = engine_name.constantize
      full = engine.root.join("app/views", path)
      flunk("gem template missing at #{full}") unless File.exist?(full)

      actual = Digest::SHA256.hexdigest(File.binread(full))
      return if expected.to_s == actual

      message = <<~MSG
        AB override for #{target_key} is stale.
        Expected digest: #{expected}
        Actual digest:   #{actual}
        Refresh the host control copy of #{path} from #{engine_name} and update source_template digest.
        Hint: diff the gem file against the host control partial registered on this target.
      MSG
      flunk(message)
    end

    def self.digest_for(engine_name, path)
      engine = engine_name.constantize
      full = engine.root.join("app/views", path)
      Digest::SHA256.hexdigest(File.binread(full))
    end
  end
end
