# frozen_string_literal: true

module RecordingStudioAbTests
  class IdentityLinker
    class << self
      def link!(visitor_id:, user:, source:)
        return if visitor_id.blank? || user.nil?

        user_id = RecordingStudioAbTests.configuration.user_identifier.call(user).to_s
        return if user_id.blank?

        now = Time.current
        link_visitor_rows!(visitor_id: visitor_id.to_s, user_id: user_id, source: source.to_s, now: now)
        promote_user_scoped!(visitor_id: visitor_id.to_s, user_id: user_id, now: now)
      end

      private

      def link_visitor_rows!(visitor_id:, user_id:, source:, now:)
        conflicting = Assignment.where(
          subject_type: "visitor",
          subject_identifier: visitor_id
        ).where.not(linked_user_id: [nil, user_id])

        if conflicting.exists?
          Rails.logger.warn(
            "[RecordingStudioAbTests] visitor #{visitor_id} already linked to another user; skipping relink"
          )
        end

        Assignment.where(
          subject_type: "visitor",
          subject_identifier: visitor_id,
          linked_user_id: nil
        ).update_all(
          linked_user_id: user_id,
          linked_at: now,
          link_source: source,
          updated_at: now
        )
      end

      def promote_user_scoped!(visitor_id:, user_id:, now:)
        visitor_rows = Assignment.where(subject_type: "visitor", subject_identifier: visitor_id).to_a
        return if visitor_rows.empty?

        experiment_ids = visitor_rows.map(&:experiment_id).uniq
        experiments = Experiment.where(id: experiment_ids, assignment_scope: "user").index_by(&:id)

        visitor_rows.each do |visitor_row|
          experiment = experiments[visitor_row.experiment_id]
          next unless experiment

          existing_user = Assignment.find_by(
            experiment_id: visitor_row.experiment_id,
            subject_type: "user",
            subject_identifier: user_id
          )
          next if existing_user # user row wins; visitor stays as history

          attrs = {
            id: SecureRandom.uuid,
            experiment_id: visitor_row.experiment_id,
            variant_id: visitor_row.variant_id,
            subject_type: "user",
            subject_identifier: user_id,
            root_recording_id: visitor_row.root_recording_id,
            allocation_version: visitor_row.allocation_version,
            bucket: visitor_row.bucket,
            assigned_at: visitor_row.assigned_at,
            linked_user_id: user_id,
            linked_at: now,
            link_source: visitor_row.link_source || "promotion",
            promoted_from_assignment_id: visitor_row.id,
            created_at: now,
            updated_at: now
          }
          Assignment.insert_all([attrs], unique_by: :idx_rsab_assignments_subject)
        end
      end
    end
  end
end
