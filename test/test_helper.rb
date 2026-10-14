# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 extracts Object#stub into the minitest-mock gem. The dummy
  # bundle does not load that gem; only the gem suite stubs methods.
end
require "rails"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_ab_tests"

# Gem-suite unit tests do not boot the engine. Mirror the boot-time
# register_shipped_english so RecordingStudio.t can fall back to this gem's
# English when keys are deleted from the loaded backend. Do not call the
# engine initializer block from tests — dummy integration asserts registration
# from a real boot.
RecordingStudio::Translation.register_shipped_english(
  File.expand_path("../config/locales/en.yml", __dir__)
)
