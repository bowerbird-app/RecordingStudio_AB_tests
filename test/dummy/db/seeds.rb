# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"

# --- A/B demos (no Admin yet) -------------------------------------------------
seed_experiment = lambda do |key:, name:, target_key:, status:|
  experiment = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: key)
  if experiment.new_record?
    experiment.assign_attributes(
      name: name,
      target_key: target_key,
      assignment_scope: "visitor",
      traffic_percentage: 100,
      status: "draft",
      allocation_version: "sha256-v1",
      allocation_seed: SecureRandom.hex(8),
      created_by: user
    )
    experiment.save!
  else
    experiment.update!(name: name) if experiment.name != name
  end

  if experiment.variants.none?
    experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                is_control: true, weight: 50, position: 0)
    experiment.variants.create!(key: "b", name: "Variant B", implementation_key: "b",
                                is_control: false, weight: 50, position: 1)
  end

  if experiment.goals.none?
    experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup",
                             is_primary: true, attribution_window_hours: 168,
                             counting_policy: "once_per_participant")
  end

  if status == "running" && experiment.draft?
    experiment.update!(status: "running", started_at: Time.current)
  end

  experiment
end

pricing_draft = seed_experiment.call(
  key: "pricing_draft_demo",
  name: "Pricing (draft)",
  target_key: "pricing_page",
  status: "draft"
)
pricing_running = seed_experiment.call(
  key: "pricing_running_demo",
  name: "Pricing (running)",
  target_key: "pricing_page",
  status: "running"
)
hero_running = seed_experiment.call(
  key: "hero_running_demo",
  name: "Hero (running)",
  target_key: "hero_component",
  status: "running"
)

# Only one live experiment per target — archive the draft's conflict by keeping
# pricing_running as the live experiment. The draft uses a different key and
# remains draft so ActiveSet ignores it for serving.
RecordingStudioAbTests::ActiveSet.bump!

puts "Seeded AB: #{pricing_draft.key} (draft), #{pricing_running.key} (running), #{hero_running.key} (running)"
