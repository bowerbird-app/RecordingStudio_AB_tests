# frozen_string_literal: true

module RecordingStudioAbTests
  module Adapters
    module View
      module_function

      def render(controller, target, **opts)
        resolution = AssignmentResolver.resolve(target.key, expose: true)
        rails_variant = resolution.rails_variant
        status = opts.delete(:status)
        layout = opts.key?(:layout) ? opts.delete(:layout) : true

        render_opts = opts.merge(template: target.template, layout: layout)
        render_opts[:status] = status if status
        render_opts[:variants] = [rails_variant] if rails_variant && resolution.variant_key.to_s != "control"

        if target.request_variant && rails_variant && resolution.variant_key.to_s != "control"
          previous = Array(controller.request.variant)
          begin
            controller.request.variant = previous + [rails_variant]
            controller.render(**render_opts.except(:variants))
          ensure
            controller.request.variant = previous
          end
        else
          # Scoped to this render call only — do not mutate request.variant
          controller.render(**render_opts)
        end
      end
    end
  end
end
