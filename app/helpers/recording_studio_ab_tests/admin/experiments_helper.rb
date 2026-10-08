# frozen_string_literal: true

module RecordingStudioAbTests
  module Admin
    module ExperimentsHelper
      STATUS_BADGE_STYLES = {
        "draft" => :default,
        "running" => :success,
        "paused" => :warning,
        "completed" => :info,
        "archived" => :default
      }.freeze

      TAB_INDEXES = {
        "configuration" => 0,
        "variants" => 1,
        "goals" => 2,
        "results" => 3
      }.freeze

      def status_badge_style(status)
        STATUS_BADGE_STYLES.fetch(status.to_s, :default)
      end

      def tab_index_for(tab)
        TAB_INDEXES.fetch(tab.to_s, 0)
      end
    end
  end
end
