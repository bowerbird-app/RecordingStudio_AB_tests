# frozen_string_literal: true

require "digest"

namespace :recording_studio_ab_tests do
  desc "Verify host AB overrides match the pinned gem template digests (plan §14)"
  task verify_overrides: :environment do
    failures = []

    RecordingStudioAbTests.registry.targets.each_value do |target|
      source = target.source_template
      next unless source

      engine_name = source[:engine] || source["engine"]
      path = source[:path] || source["path"]
      expected = source[:digest] || source["digest"]
      if engine_name.blank? || path.blank? || expected.blank?
        failures << "#{target.key}: incomplete source_template"
        next
      end

      begin
        engine = engine_name.constantize
      rescue NameError => e
        failures << "#{target.key}: #{e.message}"
        next
      end

      full = engine.root.join("app/views", path)
      unless File.exist?(full)
        failures << "#{target.key}: gem template missing at #{full}"
        next
      end

      actual = Digest::SHA256.hexdigest(File.binread(full))
      next if actual == expected.to_s

      failures << "#{target.key}: digest mismatch for #{path} (expected #{expected}, got #{actual}). " \
                  "Refresh the host control copy and update source_template digest."
    end

    if failures.empty?
      puts "recording_studio_ab_tests:verify_overrides OK"
    else
      warn "recording_studio_ab_tests:verify_overrides FAILED:"
      failures.each { |f| warn "  - #{f}" }
      abort
    end
  end

  desc "Measure AB hot-path latency and SQL (writes tmp/ab_benchmark.md; not a CI gate)"
  task benchmark: :environment do
    require "benchmark"

    iterations = Integer(ENV.fetch("AB_BENCHMARK_ITERS", "40"))
    out_path = Rails.root.join("tmp/ab_benchmark.md")
    FileUtils.mkdir_p(File.dirname(out_path))

    helper = Object.new.extend(Module.new do
      def clear!
        RecordingStudioAbTests::Conversion.delete_all
        RecordingStudioAbTests::Exposure.delete_all
        RecordingStudioAbTests::Assignment.delete_all
        RecordingStudioAbTests::Goal.delete_all
        RecordingStudioAbTests::Variant.delete_all
        RecordingStudioAbTests::Experiment.delete_all
        RecordingStudioAbTests::ActiveSet.clear_local!
        Rails.cache.clear
      end

      def create_running!(key:, target_key:, scope: "visitor", weights: [50, 50], seed: "benchseed01234567")
        experiment = RecordingStudioAbTests::Experiment.create!(
          key: key, name: key, target_key: target_key, assignment_scope: scope,
          traffic_percentage: 100, allocation_seed: seed, allocation_version: "sha256-v1", status: "draft"
        )
        experiment.variants.create!(key: "control", name: "Control", implementation_key: "control",
                                    is_control: true, weight: weights[0], position: 0)
        experiment.variants.create!(key: "b", name: "B", implementation_key: "b",
                                    is_control: false, weight: weights[1], position: 1)
        experiment.goals.create!(key: "primary", name: "Primary", event_key: "demo_signup", is_primary: true)
        experiment.update!(status: "running", started_at: Time.current)
        RecordingStudioAbTests::ActiveSet.reload!
        experiment
      end

      def with_request(path: "/demo/pricing", user: nil)
        env = Rack::MockRequest.env_for(path, "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Bench/1.0)")
        request = ActionDispatch::Request.new(env)
        RecordingStudioAbTests::Current.reset
        RecordingStudioAbTests::Current.request = request
        if user
          RecordingStudioAbTests::Current.user_identifier =
            RecordingStudioAbTests.configuration.user_identifier.call(user)
        end
        yield request
      ensure
        RecordingStudioAbTests::Current.reset
      end

      def percentile(samples, p)
        return 0.0 if samples.empty?

        sorted = samples.sort
        idx = ((p / 100.0) * (sorted.length - 1)).round
        sorted[idx]
      end

      def measure(label, iterations:)
        latencies = []
        sql_reads = []
        sql_writes = []
        cache_reads = []

        iterations.times do
          queries = []
          caches = 0
          sql_sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
            sql = payload[:sql].to_s
            next if sql.match?(/\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)
            next if sql.include?("schema_migrations")

            queries << sql
          end
          cache_sub = ActiveSupport::Notifications.subscribe("cache_read.active_support") do |*|
            caches += 1
          end

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          yield
          elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0
          latencies << elapsed_ms
          writes = queries.count { |q| q.match?(/\A(INSERT|UPDATE|DELETE)/i) }
          sql_writes << writes
          sql_reads << (queries.size - writes)
          cache_reads << caches
        ensure
          ActiveSupport::Notifications.unsubscribe(sql_sub) if sql_sub
          ActiveSupport::Notifications.unsubscribe(cache_sub) if cache_sub
        end

        {
          label: label,
          p50_ms: percentile(latencies, 50).round(3),
          p95_ms: percentile(latencies, 95).round(3),
          sql_reads_avg: (sql_reads.sum.to_f / sql_reads.size).round(2),
          sql_writes_avg: (sql_writes.sum.to_f / sql_writes.size).round(2),
          cache_reads_avg: (cache_reads.sum.to_f / cache_reads.size).round(2)
        }
      end
    end)

    results = []
    original_enabled = RecordingStudioAbTests.configuration.enabled
    original_mode = RecordingStudioAbTests.configuration.exposure_mode

    begin
      helper.clear!

      # 1. AB disabled
      RecordingStudioAbTests.configuration.enabled = false
      RecordingStudioAbTests.configuration.exposure_mode = :inline
      results << helper.measure("AB disabled", iterations: iterations) do
        helper.with_request do
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end

      # 2. Registered target, no running experiment
      RecordingStudioAbTests.configuration.enabled = true
      helper.clear!
      results << helper.measure("Registered target, no running experiment", iterations: iterations) do
        helper.with_request do
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end

      # 3. First-time visitor
      helper.clear!
      helper.create_running!(key: "bench_first", target_key: "pricing_page")
      results << helper.measure("First-time visitor (assign + expose inline)", iterations: iterations) do
        helper.with_request do
          RecordingStudioAbTests::Current.visitor_id = SecureRandom.uuid
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end

      # 4. Returning visitor (cookie / existing assignment hit)
      helper.clear!
      helper.create_running!(key: "bench_return", target_key: "pricing_page")
      vid = SecureRandom.uuid
      helper.with_request do
        RecordingStudioAbTests::Current.visitor_id = vid
        RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
      end
      results << helper.measure("Returning visitor (existing assignment)", iterations: iterations) do
        helper.with_request do |request|
          RecordingStudioAbTests::Current.visitor_id = vid
          request.cookie_jar.signed[RecordingStudioAbTests::Identity::VISITOR_COOKIE] = vid
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end

      # 5. Authenticated user
      helper.clear!
      user = User.find_or_create_by!(email: "bench@example.com") do |u|
        u.password = "Password"
        u.password_confirmation = "Password"
      end
      helper.create_running!(key: "bench_user", target_key: "pricing_page", scope: "user")
      results << helper.measure("Authenticated user", iterations: iterations) do
        helper.with_request(user: user) do
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end

      # 6. Partial / component resolve (resolution only; render needs full view context)
      helper.clear!
      helper.create_running!(key: "bench_partial", target_key: "presskit_cta")
      results << helper.measure("Partial target resolve", iterations: iterations) do
        helper.with_request(path: "/demo/presskit") do
          RecordingStudioAbTests::Current.visitor_id = SecureRandom.uuid
          RecordingStudioAbTests::AssignmentResolver.resolve(:presskit_cta, expose: true)
        end
      end

      helper.clear!
      helper.create_running!(key: "bench_component", target_key: "hero_component")
      results << helper.measure("Component target resolve", iterations: iterations) do
        helper.with_request(path: "/demo/hero") do
          RecordingStudioAbTests::Current.visitor_id = SecureRandom.uuid
          RecordingStudioAbTests::AssignmentResolver.resolve(:hero_component, expose: true)
        end
      end

      # 7. track_event with 0 / 1 / 5 matching goals
      [0, 1, 5].each do |goal_count|
        helper.clear!
        experiment = helper.create_running!(key: "bench_evt_#{goal_count}", target_key: "pricing_page", scope: "user")
        if goal_count > 1
          (2..goal_count).each do |i|
            experiment.goals.create!(
              key: "g#{i}", name: "Goal #{i}", event_key: "demo_signup",
              is_primary: false, attribution_window_hours: 168, counting_policy: "once_per_participant"
            )
          end
        elsif goal_count.zero?
          experiment.goals.delete_all
        end
        results << helper.measure("track_event (#{goal_count} matching goals)", iterations: iterations) do
          RecordingStudioAbTests.track_event(:demo_signup, subject: user, event_id: SecureRandom.uuid)
        end
      end

      # 8. Concurrent first assignment → one row
      helper.clear!
      helper.create_running!(key: "bench_conc", target_key: "pricing_page")
      subject_id = "concurrent-bench-subject"
      threads = 20
      barrier = Queue.new
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      workers = threads.times.map do
        Thread.new do
          barrier.pop
          RecordingStudioAbTests::Current.reset
          env = Rack::MockRequest.env_for("/demo/pricing", "HTTP_USER_AGENT" => "Mozilla/5.0 Bench")
          RecordingStudioAbTests::Current.request = ActionDispatch::Request.new(env)
          RecordingStudioAbTests::Current.visitor_id = subject_id
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: false)
        ensure
          RecordingStudioAbTests::Current.reset
        end
      end
      threads.times { barrier << true }
      workers.each(&:join)
      concurrent_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(3)
      row_count = RecordingStudioAbTests::Assignment.where(
        subject_type: "visitor", subject_identifier: subject_id
      ).count
      results << {
        label: "20 concurrent first assignments (one row assert)",
        p50_ms: concurrent_ms,
        p95_ms: concurrent_ms,
        sql_reads_avg: "n/a",
        sql_writes_avg: "n/a",
        cache_reads_avg: "n/a",
        note: "assignment_rows=#{row_count} (expected 1)"
      }

      # Async exposure mode sample
      helper.clear!
      RecordingStudioAbTests.configuration.exposure_mode = :async
      helper.create_running!(key: "bench_async", target_key: "pricing_page")
      results << helper.measure("First-time visitor (expose async)", iterations: iterations) do
        helper.with_request do
          RecordingStudioAbTests::Current.visitor_id = SecureRandom.uuid
          RecordingStudioAbTests::AssignmentResolver.resolve(:pricing_page, expose: true)
        end
      end
    ensure
      RecordingStudioAbTests.configuration.enabled = original_enabled
      RecordingStudioAbTests.configuration.exposure_mode = original_mode
    end

    lines = []
    lines << "# RecordingStudioAbTests benchmark"
    lines << ""
    lines << "Generated at #{Time.current.utc.iso8601} · iterations=#{iterations} · " \
             "Rails #{Rails.version} · env=#{Rails.env}"
    lines << ""
    lines << "| Scenario | p50 (ms) | p95 (ms) | SQL reads (avg) | SQL writes (avg) | Cache reads (avg) | Notes |"
    lines << "| --- | ---: | ---: | ---: | ---: | ---: | --- |"
    results.each do |row|
      lines << "| #{row[:label]} | #{row[:p50_ms]} | #{row[:p95_ms]} | #{row[:sql_reads_avg]} | " \
               "#{row[:sql_writes_avg]} | #{row[:cache_reads_avg]} | #{row[:note]} |"
    end
    lines << ""
    lines << "Not a CI gate. Numbers are environment-specific; no production claims beyond these measurements."
    lines << ""

    File.write(out_path, lines.join("\n"))
    puts lines.join("\n")
    puts "Wrote #{out_path}"
  end
end
