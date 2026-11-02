# frozen_string_literal: true

require "test_helper"

class CookieCodecTest < Minitest::Test
  FakeJar = Struct.new(:value) do
    def signed
      self
    end

    def [](_name)
      value
    end

    def []=(*)
      nil
    end
  end

  FakeRequest = Struct.new(:cookie_jar)

  def test_put_entry_does_not_store_vid
    payload = RecordingStudioAbTests::CookieCodec.empty_payload.merge("vid" => "old")
    updated = RecordingStudioAbTests::CookieCodec.put_entry(
      payload,
      experiment_id: "exp-1",
      variant_key: "b",
      target_key: "pricing_page"
    )

    refute updated.key?("vid")
    assert_equal ["b", ["pricing_page"]], updated.dig("a", "exp-1")
  end

  def test_read_returns_empty_payload_for_invalid_json
    request = FakeRequest.new(FakeJar.new("{not json"))
    payload = RecordingStudioAbTests::CookieCodec.read(request)

    assert_equal RecordingStudioAbTests::CookieCodec.empty_payload, payload
  end

  def test_empty_payload_omits_vid
    refute RecordingStudioAbTests::CookieCodec.empty_payload.key?("vid")
  end
end
