# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.layout = "admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  config.access_recording_resolver = lambda do |context|
    RecordingStudioAccessible.admin_root(context: context)
  end

  # Site admin is the Admin root, not whichever workspace the switcher has
  # selected. Admin 2.16 forbids the page when those two recordings differ.
  config.current_root_recording_resolver = lambda do |context|
    RecordingStudioAccessible.admin_root(context: context)
  end

  config.admin_action_auditor = lambda do |event|
    AdminAuditLog.record_admin_action!(event) if defined?(AdminAuditLog) && AdminAuditLog.table_exists?
  end
end

Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/root/section.rb")
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
