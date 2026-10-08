# frozen_string_literal: true

require "digest"

module RecordingStudioAbTests
  module TestHelpers
    # Recomputes the digest of a gem template referenced by source_template: and
    # fails when the host override copy is stale. Full drift-guard usage lands in PR2.
    def assert_ab_override_current(target_key)
      target = RecordingStudioAbTests.registry.fetch_target!(target_key)
      source = target.source_template
      raise "target #{target_key} has no source_template:" unless source

      engine_name = source[:engine] || source["engine"]
      path = source[:path] || source["path"]
      expected = source[:digest] || source["digest"]
      engine = engine_name.constantize
      full = engine.root.join("app/views", path)
      actual = Digest::SHA256.hexdigest(File.binread(full))
      assert_equal expected, actual,
                   "AB override for #{target_key} is stale; refresh the host control copy of #{path}"
    end
  end
end
