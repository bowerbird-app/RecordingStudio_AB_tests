# frozen_string_literal: true

module RecordingStudioAbTests
  # Wraps variant HTML in RecordingStudioCache (preferred) or Rails.cache.
  # Keys never include visitor or user ids — only ab_cache_vary hashes (plan §26).
  module FragmentCache
    module_function

    def fetch(cache_opts, vary:, &block)
      raise ArgumentError, "cache: requires a block" unless block

      opts = (cache_opts || {}).transform_keys(&:to_sym)
      recording = opts[:recording]
      entry = opts[:entry]
      policy = opts[:policy]
      expires_in = opts[:expires_in]
      race_ttl = opts[:race_ttl]

      if recording_studio_cache_available? && recording
        fetch_options = { vary: vary }
        fetch_options[:policy] = policy if policy
        fetch_options[:expires_in] = expires_in if expires_in
        fetch_options[:race_ttl] = race_ttl if race_ttl
        value = RecordingStudioCache.fetch(recording, entry, **fetch_options, &block)
      else
        key = [entry || :ab_fragment, vary]
        value = Rails.cache.fetch(key, expires_in: expires_in, &block)
      end
      mark_html_safe(value)
    end

    def recording_studio_cache_available?
      defined?(RecordingStudioCache) && RecordingStudioCache.respond_to?(:fetch)
    end
    module_function :recording_studio_cache_available?

    def mark_html_safe(value)
      return value if value.nil?
      return value if value.respond_to?(:html_safe?) && value.html_safe?
      # Cache backends may strip SafeBuffer; variant HTML is host-authored.
      return value.html_safe if value.respond_to?(:html_safe)

      value
    end
    module_function :mark_html_safe
  end
end
