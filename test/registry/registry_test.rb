# frozen_string_literal: true

require "test_helper"

class RegistryTest < Minitest::Test
  def setup
    @original = RecordingStudioAbTests.registry
    RecordingStudioAbTests.instance_variable_set(:@registry, RecordingStudioAbTests::Registry.new)
  end

  def teardown
    RecordingStudioAbTests.instance_variable_set(:@registry, @original)
  end

  def test_register_and_fetch_target
    RecordingStudioAbTests.register_target :pricing_page, type: :view,
                                                          template: "pricing/show",
                                                          variants: { b: { rails_variant: :ab_pricing_b } }

    target = RecordingStudioAbTests.registry.fetch_target!(:pricing_page)
    assert_equal :view, target.type
    assert_equal :ab_pricing_b, target.rails_variant_for(:b)
  end

  def test_unknown_target_raises
    assert_raises(RecordingStudioAbTests::UnknownTarget) do
      RecordingStudioAbTests.registry.fetch_target!(:missing)
    end
  end

  def test_invalid_registration_raises_in_test
    assert_raises(RecordingStudioAbTests::InvalidTarget) do
      RecordingStudioAbTests.register_target :bad, type: :view
    end
  end

  def test_control_variant_key_rejected
    assert_raises(RecordingStudioAbTests::InvalidTarget) do
      RecordingStudioAbTests.register_target :bad, type: :view,
                                                   template: "x",
                                                   variants: { control: { rails_variant: :ab_x } }
    end
  end

  def test_reregister_replaces
    RecordingStudioAbTests.register_target :t, type: :view, template: "a"
    RecordingStudioAbTests.register_target :t, type: :view, template: "b"
    assert_equal "b", RecordingStudioAbTests.registry.target(:t).template
  end

  def test_register_event
    RecordingStudioAbTests.register_event :presskit_created, label: "Press kit", subject: :user
    assert_equal :user, RecordingStudioAbTests.registry.event(:presskit_created).subject
  end

  def test_no_host_variant_code_under_gem_app
    gem_app = File.expand_path("../../app", __dir__)
    hits = Dir.glob("#{gem_app}/**/*.{erb,rb}").select do |path|
      content = File.read(path)
      content.include?("ab_pricing_b") || content.include?("HeroVariantB")
    end
    assert_empty hits, "host variant code must not live under gem app/: #{hits}"
  end
end
