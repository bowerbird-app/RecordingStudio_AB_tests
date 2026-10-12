# frozen_string_literal: true

# Generator follow-up; no-op when actor_id is already string (dummy create is).
class ChangeRecordingStudioRootSwitchableSelectionActorIdToString < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:recording_studio_root_switchable_selections)
    return unless column_exists?(:recording_studio_root_switchable_selections, :actor_id)

    column = connection.columns(:recording_studio_root_switchable_selections).find { |c| c.name == "actor_id" }
    return if column && column.type == :string

    change_column :recording_studio_root_switchable_selections,
                  :actor_id,
                  :string,
                  using: "actor_id::text"
  end

  def down
    return unless table_exists?(:recording_studio_root_switchable_selections)
    return unless column_exists?(:recording_studio_root_switchable_selections, :actor_id)

    change_column :recording_studio_root_switchable_selections,
                  :actor_id,
                  :uuid,
                  using: "actor_id::uuid"
  end
end
