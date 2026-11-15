# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]

  # Site-wide admin screens need this kept root. Admin 2.16 reads it through
  # RecordingStudioAccessible.admin_root.
  config.admin_root_resolver = lambda do |context: nil|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.kept.find_by(recordable: admin_root)
  end
end
