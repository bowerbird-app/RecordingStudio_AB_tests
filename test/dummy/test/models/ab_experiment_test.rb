# frozen_string_literal: true

require "test_helper"
require_relative "../ab_tests_helper"

class AbExperimentTest < ActiveSupport::TestCase
  include AbTestsHelper

  setup do
    RecordingStudioAbTests::Conversion.delete_all
    RecordingStudioAbTests::Exposure.delete_all
    RecordingStudioAbTests::Assignment.delete_all
    RecordingStudioAbTests::Goal.delete_all
    RecordingStudioAbTests::Variant.delete_all
    RecordingStudioAbTests::Experiment.delete_all
    RecordingStudioAbTests::ActiveSet.clear_local!
  end

  test "validations for key status scope and traffic" do
    experiment = RecordingStudioAbTests::Experiment.new(
      key: "Bad Key",
      name: "X",
      target_key: "pricing_page",
      assignment_scope: "workspace",
      traffic_percentage: 150
    )
    refute experiment.valid?
    assert_includes experiment.errors[:key], "is invalid"
    assert_includes experiment.errors[:assignment_scope], "is not included in the list"
    assert experiment.errors[:traffic_percentage].any?
  end

  test "lifecycle transitions and frozen fields" do
    experiment = create_running_experiment!(key: "life_exp", target_key: "pricing_page")

    refute experiment.update(key: "other_key")
    assert_includes experiment.errors[:key], "cannot change after experiment has started"
    assert experiment.errors.of_kind?(:key, :frozen_after_start)
    assert_equal [{ error: :frozen_after_start }], experiment.errors.details[:key]
    experiment.reload

    assert RecordingStudioAbTests::Lifecycle.pause!(experiment)
    assert experiment.reload.paused?

    assert RecordingStudioAbTests::Lifecycle.resume!(experiment)
    assert experiment.reload.running?

    assert RecordingStudioAbTests::Lifecycle.complete!(experiment)
    assert experiment.reload.completed?

    assert RecordingStudioAbTests::Lifecycle.archive!(experiment)
    assert experiment.reload.archived?
  end

  test "custom validation errors keep symbol types in errors.details" do
    experiment = create_running_experiment!(key: "err_types", target_key: "pricing_page")
    control = experiment.variants.find_by!(is_control: true)
    primary = experiment.goals.find_by!(is_primary: true)

    refute experiment.update(key: "renamed")
    assert_equal [{ error: :frozen_after_start }], experiment.errors.details[:key]
    assert experiment.errors.of_kind?(:key, :frozen_after_start)
    assert experiment.errors.added?(:key, :frozen_after_start)
    assert_includes experiment.errors[:key], "cannot change after experiment has started"
    experiment.reload

    refute primary.update(event_key: "other_event")
    assert_equal [{ error: :primary_event_frozen }], primary.errors.details[:event_key]
    assert primary.errors.of_kind?(:event_key, :primary_event_frozen)
    assert_includes primary.errors[:event_key], "primary goal event is frozen after start"

    refute control.update(key: "renamed_control")
    assert_equal [{ error: :variant_identity_frozen }], control.errors.details[:base]
    assert control.errors.of_kind?(:base, :variant_identity_frozen)
    assert_includes control.errors[:base], "variant identity is frozen after start"

    extra = experiment.variants.build(
      key: "late",
      name: "Late",
      implementation_key: "late",
      is_control: false,
      weight: 1,
      position: 9
    )
    refute extra.valid?
    assert_equal [{ error: :cannot_add_variants_after_start }], extra.errors.details[:base]
    assert extra.errors.of_kind?(:base, :cannot_add_variants_after_start)
    assert_includes extra.errors[:base], "cannot add variants after start"

    assignment = experiment.assignments.create!(
      variant: control,
      subject_type: "visitor",
      subject_identifier: "err-types-visitor",
      allocation_version: experiment.allocation_version,
      bucket: 1,
      assigned_at: Time.current
    )
    refute assignment.update(subject_identifier: "mutated")
    assert_equal [{ error: :assignment_immutable }], assignment.errors.details[:base]
    assert assignment.errors.of_kind?(:base, :assignment_immutable)
    assert_match(/assignments are immutable/, assignment.errors[:base].first)

    huge = { "pad" => "x" * (RecordingStudioAbTests::Exposure::MAX_METADATA_BYTES + 64) }
    exposure = experiment.exposures.build(
      variant: control,
      assignment: assignment,
      target_key: experiment.target_key,
      first_exposed_at: Time.current,
      last_exposed_at: Time.current,
      exposure_count: 1,
      metadata: huge
    )
    refute exposure.valid?
    assert_equal [{ error: :metadata_too_large }], exposure.errors.details[:metadata]
    assert exposure.errors.of_kind?(:metadata, :metadata_too_large)
    assert_includes exposure.errors[:metadata], "exceeds #{RecordingStudioAbTests::Exposure::MAX_METADATA_BYTES} bytes"

    conversion = experiment.conversions.build(
      variant: control,
      assignment: assignment,
      goal: primary,
      source_event_key: primary.event_key,
      idempotency_key: "err-types-conversion",
      occurred_at: Time.current,
      metadata: huge
    )
    refute conversion.valid?
    assert_equal [{ error: :metadata_too_large }], conversion.errors.details[:metadata]
    assert conversion.errors.of_kind?(:metadata, :metadata_too_large)
    assert_includes conversion.errors[:metadata], "exceeds #{RecordingStudioAbTests::Conversion::MAX_METADATA_BYTES} bytes"
  end

  test "duplicate copies variants goals with new key and seed" do
    experiment = create_running_experiment!(key: "dup_exp", target_key: "pricing_page")
    copy = RecordingStudioAbTests::Lifecycle.duplicate(experiment)

    assert_equal "dup_exp_copy_1", copy.key
    assert_equal "draft", copy.status
    refute_equal experiment.allocation_seed, copy.allocation_seed
    assert_equal 2, copy.variants.count
    assert_equal 1, copy.goals.count
  end

  test "exactly one control enforced by partial unique index" do
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "ctrl_exp",
      name: "Ctrl",
      target_key: "pricing_page",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "seedseed",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "C", implementation_key: "control",
                                is_control: true, weight: 1, position: 0)
    assert_raises(ActiveRecord::RecordNotUnique) do
      experiment.variants.create!(key: "c2", name: "C2", implementation_key: "c2",
                                  is_control: true, weight: 1, position: 1)
    end
  end

  test "start validation requires primary goal and registered target" do
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: "start_exp",
      name: "Start",
      target_key: "pricing_page",
      assignment_scope: "visitor",
      traffic_percentage: 100,
      allocation_seed: "seedseed",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "C", implementation_key: "control",
                                is_control: true, weight: 1, position: 0)

    error = assert_raises(RecordingStudioAbTests::LifecycleError) do
      RecordingStudioAbTests::Lifecycle.start!(experiment)
    end
    assert_match(/primary goal/, error.message)
  end
end
