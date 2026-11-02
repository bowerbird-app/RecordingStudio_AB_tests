# frozen_string_literal: true

module AbTestsHelper
  BROWSER_UA = { "User-Agent" => "Mozilla/5.0 (compatible; ABTest/1.0)" }.freeze

  # FK order: conversions → exposures → assignments → goals → variants → experiments.
  # Seeded traffic from db:prepare survives into CI unless cleared this way.
  def clear_ab_tables!
    RecordingStudioAbTests::Conversion.delete_all
    RecordingStudioAbTests::Exposure.delete_all
    RecordingStudioAbTests::Assignment.delete_all
    RecordingStudioAbTests::Goal.delete_all
    RecordingStudioAbTests::Variant.delete_all
    RecordingStudioAbTests::Experiment.delete_all
  end

  def create_running_experiment!(key:, target_key:, scope: "visitor", traffic: 100, weights: [50, 50], seed: "abcd1234efgh5678")
    experiment = RecordingStudioAbTests::Experiment.create!(
      key: key,
      name: key.to_s.humanize,
      target_key: target_key,
      assignment_scope: scope,
      traffic_percentage: traffic,
      allocation_seed: seed,
      allocation_version: "sha256-v1",
      status: "draft"
    )
    experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                is_control: true, weight: weights[0], position: 0)
    experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                is_control: false, weight: weights[1], position: 1)
    experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup",
                             is_primary: true)
    experiment.update!(status: "running", started_at: Time.current)
    RecordingStudioAbTests::ActiveSet.reload!
    experiment
  end

  def count_sql
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      next if sql.match?(/\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)
      next if sql.include?("schema_migrations")

      queries << sql
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def with_ab_config(**attrs)
    config = RecordingStudioAbTests.configuration
    originals = attrs.keys.index_with { |k| config.public_send(k) }
    attrs.each { |k, v| config.public_send("#{k}=", v) }
    yield
  ensure
    originals.each { |k, v| config.public_send("#{k}=", v) }
  end
end
