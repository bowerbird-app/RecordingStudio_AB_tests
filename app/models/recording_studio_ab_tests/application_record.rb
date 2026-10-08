# frozen_string_literal: true

module RecordingStudioAbTests
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
