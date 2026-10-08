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
admin_root = AdminRoot.find_or_create_by!(name: "Admin")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  # Grant the seeded admin owner access so Admin + workspace-scoped flows work.
  [ root_recording, accessible_root_recording, admin_root_recording ].each do |recording|
    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: recording,
      actor: user
    )
    raise result.error if result.failure?
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: AdminRoot '#{admin_root.name}' with root recording ##{admin_root_recording.id}"
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

# Demo C/D: signup page experiment (weights favor B for demos) with registration goals.
signup_running = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "signup_running_demo")
if signup_running.new_record?
  signup_running.assign_attributes(
    name: "Signup page (running)",
    target_key: "signup_page",
    assignment_scope: "visitor",
    traffic_percentage: 100,
    status: "draft",
    allocation_version: "sha256-v1",
    allocation_seed: SecureRandom.hex(8),
    created_by: user
  )
  signup_running.save!
end
if signup_running.variants.none?
  signup_running.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                  is_control: true, weight: 20, position: 0)
  signup_running.variants.create!(key: "b", name: "Variant B", implementation_key: "b",
                                  is_control: false, weight: 80, position: 1)
end
if signup_running.goals.none?
  signup_running.goals.create!(key: "registered", name: "User registered",
                               event_key: "user_registered", is_primary: true,
                               attribution_window_hours: 168, counting_policy: "once_per_participant")
end
if signup_running.draft?
  signup_running.update!(status: "running", started_at: Time.current)
end

# Demo D: presskit track_event conversion experiment (user scope).
presskit_running = RecordingStudioAbTests::Experiment.find_or_initialize_by(key: "presskit_running_demo")
if presskit_running.new_record?
  presskit_running.assign_attributes(
    name: "Press kit (running)",
    target_key: "presskit_cta",
    assignment_scope: "user",
    traffic_percentage: 100,
    status: "draft",
    allocation_version: "sha256-v1",
    allocation_seed: SecureRandom.hex(8),
    created_by: user
  )
  presskit_running.save!
end
if presskit_running.variants.none?
  presskit_running.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                    is_control: true, weight: 50, position: 0)
  presskit_running.variants.create!(key: "b", name: "Variant B", implementation_key: "b",
                                    is_control: false, weight: 50, position: 1)
end
if presskit_running.goals.none?
  presskit_running.goals.create!(key: "presskit", name: "Press kit created",
                                 event_key: "presskit_created", is_primary: true,
                                 attribution_window_hours: 168, counting_policy: "every_event")
end
if presskit_running.draft?
  presskit_running.update!(status: "running", started_at: Time.current)
end

# Demo F: quote service
quote_running = seed_experiment.call(
  key: "quote_running_demo",
  name: "Quote strategy (running)",
  target_key: "quote_strategy",
  status: "running"
)

# Demo G: onboarding workflow (sticky across steps)
flow_running = seed_experiment.call(
  key: "flow_running_demo",
  name: "Onboarding flow (running)",
  target_key: "onboarding_flow",
  status: "running"
)

# Demo H: cached fragment
cached_running = seed_experiment.call(
  key: "cached_running_demo",
  name: "Cached hero (running)",
  target_key: "cached_hero",
  status: "running"
)

# Lifecycle demo experiments (paused / completed / archived) so Admin screens
# can filter every status. Paused uses a dedicated target_key because
# idx_rsab_experiments_live_target allows only one running|paused per target.
paused = seed_experiment.call(
  key: "admin_paused_demo",
  name: "Admin paused demo",
  target_key: "admin_paused_target",
  status: "draft"
)
if paused.draft?
  paused.update!(status: "paused", started_at: 3.days.ago, paused_at: 1.day.ago)
end

completed = seed_experiment.call(
  key: "hero_completed_demo",
  name: "Hero (completed)",
  target_key: "hero_component",
  status: "draft"
)
if completed.draft? || completed.running?
  completed.update!(
    status: "completed",
    started_at: 10.days.ago,
    completed_at: 2.days.ago
  )
end

archived = seed_experiment.call(
  key: "hero_archived_demo",
  name: "Hero (archived)",
  target_key: "hero_component",
  status: "draft"
)
if archived.draft? || !archived.archived?
  archived.update!(
    status: "archived",
    started_at: 30.days.ago,
    completed_at: 20.days.ago,
    archived_at: 15.days.ago
  )
end

# Generated traffic so Admin list/detail/report screens show real rows.
# Assign even indices to control and odd to treatment. Conversion uses each
# variant's own ordinal (i/2) so an even convert_ratio does not starve variant b
# (previously `i % convert_ratio` only hit control → −100% relative lift).
seed_traffic = lambda do |experiment, visitors:, convert_ratio:, treatment_convert_ratio: nil|
  goal = experiment.goals.find_by(is_primary: true) || experiment.goals.first
  control = experiment.variants.find_by(is_control: true)
  treatment = experiment.variants.where(is_control: false).order(:position).first
  next unless goal && control && treatment

  treatment_ratio = treatment_convert_ratio || convert_ratio

  visitors.times do |i|
    variant = i.even? ? control : treatment
    subject = "seed-#{experiment.key}-#{i}"
    assignment = RecordingStudioAbTests::Assignment.find_or_create_by!(
      experiment_id: experiment.id,
      subject_type: "visitor",
      subject_identifier: subject
    ) do |row|
      row.variant_id = variant.id
      row.allocation_version = experiment.allocation_version
      row.bucket = i % 10_000
      row.assigned_at = (visitors - i).hours.ago
    end

    RecordingStudioAbTests::Exposure.find_or_create_by!(
      experiment_id: experiment.id,
      assignment_id: assignment.id
    ) do |row|
      row.variant_id = variant.id
      row.target_key = experiment.target_key
      row.first_exposed_at = assignment.assigned_at
      row.last_exposed_at = assignment.assigned_at + 5.minutes
      row.exposure_count = 1
      row.metadata = {}
    end

    ordinal = i / 2
    ratio = variant.is_control? ? convert_ratio : treatment_ratio
    next unless (ordinal % ratio).zero?

    RecordingStudioAbTests::Conversion.find_or_create_by!(
      idempotency_key: "seed-#{experiment.key}-#{subject}-#{goal.key}"
    ) do |row|
      row.experiment_id = experiment.id
      row.variant_id = variant.id
      row.assignment_id = assignment.id
      row.goal_id = goal.id
      row.source_event_key = goal.event_key
      row.source_event_id = "seed-evt-#{experiment.key}-#{i}"
      row.occurred_at = assignment.assigned_at + 1.hour
      row.value = variant.is_control? ? 1.0 : 1.5
      row.metadata = {}
    end
  end
end

# Skip generated traffic against test DBs. CI runs `rails db:prepare` without
# RAILS_ENV=test while DATABASE_URL still points at *_test, so check the DB
# name too. Dev/demo still get rows for Admin list/detail/report screens.
test_db = Rails.env.test? ||
  ActiveRecord::Base.connection_db_config.database.to_s.end_with?("_test")
unless test_db
  # treatment_convert_ratio slightly lower → positive relative lift for demos
  seed_traffic.call(pricing_running, visitors: 40, convert_ratio: 5, treatment_convert_ratio: 4)
  seed_traffic.call(hero_running, visitors: 30, convert_ratio: 4, treatment_convert_ratio: 3)
  seed_traffic.call(signup_running, visitors: 50, convert_ratio: 5, treatment_convert_ratio: 4)
  seed_traffic.call(presskit_running, visitors: 24, convert_ratio: 3, treatment_convert_ratio: 2)
  seed_traffic.call(quote_running, visitors: 20, convert_ratio: 5, treatment_convert_ratio: 4)
  seed_traffic.call(flow_running, visitors: 18, convert_ratio: 4, treatment_convert_ratio: 3)
  seed_traffic.call(cached_running, visitors: 16, convert_ratio: 4, treatment_convert_ratio: 3)
  seed_traffic.call(paused, visitors: 16, convert_ratio: 4, treatment_convert_ratio: 3)
  seed_traffic.call(completed, visitors: 20, convert_ratio: 4, treatment_convert_ratio: 3)
end

# Only one live experiment per target — archive the draft's conflict by keeping
# pricing_running as the live experiment. The draft uses a different key and
# remains draft so ActiveSet ignores it for serving.
RecordingStudioAbTests::ActiveSet.bump!

puts "Seeded AB: #{pricing_draft.key} (draft), #{pricing_running.key} (running), #{hero_running.key} (running)"
puts "Seeded AB: #{signup_running.key} (running), #{presskit_running.key} (running)"
puts "Seeded AB: #{quote_running.key} (running), #{flow_running.key} (running), #{cached_running.key} (running)"
puts "Seeded AB: #{paused.key} (paused), #{completed.key} (completed), #{archived.key} (archived)"
puts "Seeded AB traffic: assignments=#{RecordingStudioAbTests::Assignment.count} " \
     "exposures=#{RecordingStudioAbTests::Exposure.count} " \
     "conversions=#{RecordingStudioAbTests::Conversion.count}"
