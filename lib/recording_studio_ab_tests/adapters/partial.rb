# frozen_string_literal: true

module RecordingStudioAbTests
  module Adapters
    module Partial
      module_function

      def render(view, target, **opts)
        resolution = AssignmentResolver.resolve(target.key, expose: true)
        partial = opts.delete(:partial) || target.partial
        locals = opts.delete(:locals) || {}
        rails_variant = resolution.rails_variant

        render_opts = { partial: partial, locals: locals }
        render_opts[:variants] = [rails_variant] if rails_variant && resolution.variant_key.to_s != "control"

        view.render(**render_opts)
      end
    end
  end
end
