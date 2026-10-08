# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.engine_layout = "admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver

  config.admin_action_auditor = lambda do |event|
    AdminAuditLog.record_admin_action!(event) if defined?(AdminAuditLog) && AdminAuditLog.table_exists?
  end
end

Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/root/section.rb")
  RecordingStudioAdmin.register_section(AdminScreens::RootSection)
end
