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
