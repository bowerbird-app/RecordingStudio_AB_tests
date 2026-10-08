# frozen_string_literal: true

module RecordingStudioAbTests
  module ViewHelper
    def render_ab(target_key, **opts)
      target = RecordingStudioAbTests.registry.fetch_target!(target_key)
      Identity.populate_from_controller!(controller) if respond_to?(:controller)

      cache_opts = opts.delete(:cache)
      if cache_opts
        vary = ab_cache_vary(target_key)
        FragmentCache.fetch(cache_opts, vary: vary) do
          render_ab_uncached(target, **opts)
        end
      else
        render_ab_uncached(target, **opts)
      end
    end

    def ab_variant(target_key, expose: false)
      Identity.populate_from_controller!(controller) if respond_to?(:controller)
      AssignmentResolver.resolve(target_key, expose: expose).variant_key.to_sym
    end

    # Returns `{ "ab.<key>" => "variant" }` for RecordingStudioCache vary: / Rails cache keys.
    # Resolves and exposes each target before the cache lookup so hits still count exposures.
    def ab_cache_vary(*target_keys)
      target_keys.to_h do |key|
        ["ab.#{key}", ab_variant(key, expose: true).to_s]
      end
    end

    private

    def render_ab_uncached(target, **)
      case target.type
      when :partial
        Adapters::Partial.render(self, target, **)
      when :component
        Adapters::Component.render(self, target, **)
      when :view
        raise ArgumentError, "view targets must be rendered via controller#render_ab"
      when :service
        raise ArgumentError, "service targets must be called via RecordingStudioAbTests.execute"
      else
        raise UnknownTarget, "unsupported target type #{target.type}"
      end
    end
  end
end
