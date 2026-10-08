# frozen_string_literal: true

require "digest"

namespace :recording_studio_ab_tests do
  desc "Verify host AB overrides match the pinned gem template digests (plan §14)"
  task verify_overrides: :environment do
    failures = []

    RecordingStudioAbTests.registry.targets.each_value do |target|
      source = target.source_template
      next unless source

      engine_name = source[:engine] || source["engine"]
      path = source[:path] || source["path"]
      expected = source[:digest] || source["digest"]
      if engine_name.blank? || path.blank? || expected.blank?
        failures << "#{target.key}: incomplete source_template"
        next
      end

      begin
        engine = engine_name.constantize
      rescue NameError => e
        failures << "#{target.key}: #{e.message}"
        next
      end

      full = engine.root.join("app/views", path)
      unless File.exist?(full)
        failures << "#{target.key}: gem template missing at #{full}"
        next
      end

      actual = Digest::SHA256.hexdigest(File.binread(full))
      next if actual == expected.to_s

      failures << "#{target.key}: digest mismatch for #{path} (expected #{expected}, got #{actual}). " \
                  "Refresh the host control copy and update source_template digest."
    end

    if failures.empty?
      puts "recording_studio_ab_tests:verify_overrides OK"
    else
      warn "recording_studio_ab_tests:verify_overrides FAILED:"
      failures.each { |f| warn "  - #{f}" }
      abort
    end
  end
end
