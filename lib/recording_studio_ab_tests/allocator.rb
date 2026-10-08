# frozen_string_literal: true

require "digest"

module RecordingStudioAbTests
  module Allocator
    module_function

    BUCKET_MODULUS = 10_000

    def bucket(allocation_version:, purpose:, key:, seed:, subject_type:, subject_identifier:)
      input = [
        allocation_version,
        purpose,
        key,
        seed,
        subject_type,
        subject_identifier
      ].join("|")
      Digest::SHA256.hexdigest(input)[0, 8].to_i(16) % BUCKET_MODULUS
    end

    def traffic_bucket(experiment:, subject_type:, subject_identifier:)
      bucket(
        allocation_version: experiment.allocation_version,
        purpose: "traffic",
        key: experiment.key,
        seed: experiment.allocation_seed,
        subject_type: subject_type,
        subject_identifier: subject_identifier
      )
    end

    def variant_bucket(experiment:, subject_type:, subject_identifier:)
      bucket(
        allocation_version: experiment.allocation_version,
        purpose: "variant",
        key: experiment.key,
        seed: experiment.allocation_seed,
        subject_type: subject_type,
        subject_identifier: subject_identifier
      )
    end

    # Choose a variant from cumulative integer weights ordered by (position, key).
    def choose_variant(variants, variant_bucket)
      ordered = Array(variants).sort_by { |v| [v.position, v.key] }
      total = ordered.sum(&:weight)
      return ordered.find(&:is_control) || ordered.first if total <= 0

      # Map 0..9999 onto the weight range
      threshold = (variant_bucket * total) / BUCKET_MODULUS
      cumulative = 0
      ordered.each do |variant|
        cumulative += variant.weight
        return variant if threshold < cumulative
      end
      ordered.last
    end

    def in_traffic?(experiment:, subject_type:, subject_identifier:)
      traffic_bucket(
        experiment: experiment,
        subject_type: subject_type,
        subject_identifier: subject_identifier
      ) < (experiment.traffic_percentage * 100)
    end
  end
end
