# frozen_string_literal: true

require "test_helper"

class MetricsTest < Minitest::Test
  VariantStub = Struct.new(:id, :key, :name, :is_control, :position, keyword_init: true)

  def test_zero_control_rate_shows_em_dash_for_lift
    control = VariantStub.new(id: "c", key: "control", name: "Control", is_control: true, position: 0)
    treatment = VariantStub.new(id: "b", key: "b", name: "B", is_control: false, position: 1)

    rows = RecordingStudioAbTests::Metrics.build_rows(
      [control, treatment],
      {
        assignments: { "c" => 10, "b" => 10 },
        unique_exposed: { "c" => 10, "b" => 10 },
        raw_conversions: { "c" => 0, "b" => 2 },
        unique_converters: { "c" => 0, "b" => 2 },
        total_values: { "c" => 0, "b" => 5 }
      }
    )

    treatment_row = rows.find { |r| r.variant_key == "b" }
    control_row = rows.find { |r| r.variant_key == "control" }

    assert_equal "—", treatment_row.relative_lift
    assert_equal "—", control_row.relative_lift
    assert_equal "not statistically tested", treatment_row.lift_label
    assert_equal 10, treatment_row.sample_size
  end

  def test_sample_sizes_always_present_and_label_set
    control = VariantStub.new(id: "c", key: "control", name: "Control", is_control: true, position: 0)
    treatment = VariantStub.new(id: "b", key: "b", name: "B", is_control: false, position: 1)

    rows = RecordingStudioAbTests::Metrics.build_rows(
      [control, treatment],
      {
        assignments: { "c" => 20, "b" => 20 },
        unique_exposed: { "c" => 20, "b" => 20 },
        raw_conversions: { "c" => 4, "b" => 6 },
        unique_converters: { "c" => 4, "b" => 6 },
        total_values: { "c" => 0, "b" => 0 }
      }
    )

    rows.each do |row|
      assert_equal row.unique_exposed, row.sample_size
      assert_equal "not statistically tested", row.lift_label
      refute_equal "NaN", row.conversion_rate.to_s
      refute_equal "NaN", row.relative_lift.to_s
    end

    treatment_row = rows.find { |r| r.variant_key == "b" }
    assert_equal "50.0%", treatment_row.relative_lift
    assert_equal "30.0%", treatment_row.conversion_rate
  end

  def test_zero_exposed_rate_is_em_dash
    assert_equal "—", RecordingStudioAbTests::Metrics.format_rate(nil)
    assert_equal "—", RecordingStudioAbTests::Metrics.format_value_per_exposed(10, 0)
    assert_equal "not statistically tested", RecordingStudioAbTests::Metrics::LIFT_LABEL
  end
end
