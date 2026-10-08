# frozen_string_literal: true

require "test_helper"

class AllocatorTest < Minitest::Test
  ExperimentStub = Struct.new(
    :key, :allocation_seed, :allocation_version, :traffic_percentage,
    keyword_init: true
  )
  VariantStub = Struct.new(:key, :weight, :position, :is_control, keyword_init: true)

  def test_golden_hash_values
    # Fixed seeds → fixed buckets (verified algorithm from the plan)
    bucket = RecordingStudioAbTests::Allocator.bucket(
      allocation_version: "sha256-v1",
      purpose: "variant",
      key: "pricing_demo",
      seed: "abcd1234efgh5678",
      subject_type: "visitor",
      subject_identifier: "11111111-2222-3333-4444-555555555555"
    )

    expected_input = %w[
      sha256-v1 variant pricing_demo abcd1234efgh5678
      visitor 11111111-2222-3333-4444-555555555555
    ].join("|")
    expected = Digest::SHA256.hexdigest(expected_input)[0, 8].to_i(16) % 10_000

    assert_equal expected, bucket
    assert_operator bucket, :>=, 0
    assert_operator bucket, :<, 10_000
  end

  def test_traffic_and_variant_purposes_differ
    experiment = ExperimentStub.new(
      key: "exp",
      allocation_seed: "seedseed",
      allocation_version: "sha256-v1",
      traffic_percentage: 50
    )

    traffic = RecordingStudioAbTests::Allocator.traffic_bucket(
      experiment: experiment, subject_type: "visitor", subject_identifier: "s1"
    )
    variant = RecordingStudioAbTests::Allocator.variant_bucket(
      experiment: experiment, subject_type: "visitor", subject_identifier: "s1"
    )

    refute_equal traffic, variant
  end

  def test_weight_distribution_within_two_percent_over_100k
    variants = [
      VariantStub.new(key: "control", weight: 50, position: 0, is_control: true),
      VariantStub.new(key: "b", weight: 50, position: 1, is_control: false)
    ]
    experiment = ExperimentStub.new(
      key: "dist_exp",
      allocation_seed: "deadbeefcafebabe",
      allocation_version: "sha256-v1",
      traffic_percentage: 100
    )

    counts = Hash.new(0)
    100_000.times do |i|
      bucket = RecordingStudioAbTests::Allocator.variant_bucket(
        experiment: experiment,
        subject_type: "visitor",
        subject_identifier: "subject-#{i}"
      )
      chosen = RecordingStudioAbTests::Allocator.choose_variant(variants, bucket)
      counts[chosen.key] += 1
    end

    control_rate = counts["control"] / 100_000.0
    b_rate = counts["b"] / 100_000.0

    assert_in_delta 0.50, control_rate, 0.02
    assert_in_delta 0.50, b_rate, 0.02
  end

  def test_traffic_gate_independent_of_variant
    experiment = ExperimentStub.new(
      key: "traffic_exp",
      allocation_seed: "ffffffffffffffff",
      allocation_version: "sha256-v1",
      traffic_percentage: 0
    )

    refute RecordingStudioAbTests::Allocator.in_traffic?(
      experiment: experiment, subject_type: "visitor", subject_identifier: "anyone"
    )

    experiment.traffic_percentage = 100
    assert RecordingStudioAbTests::Allocator.in_traffic?(
      experiment: experiment, subject_type: "visitor", subject_identifier: "anyone"
    )
  end
end
