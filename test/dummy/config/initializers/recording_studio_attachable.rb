# frozen_string_literal: true

RecordingStudioAttachable.configure do |config|
  config.allowed_content_types = ["image/*", "application/pdf"]
  config.max_file_size = 25.megabytes
  config.max_file_count = 20
  config.enabled_attachment_kinds = %i[image file]
  config.default_listing_scope = :direct
  config.default_kind_filter = :all
  config.layout = :blank
end
