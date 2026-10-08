# frozen_string_literal: true

module RecordingStudioAbTests
  module ControllerHelper
    def render_ab(target_key, **opts)
      Identity.populate_from_controller!(self)
      target = RecordingStudioAbTests.registry.fetch_target!(target_key)

      case target.type
      when :view
        Adapters::View.render(self, target, **opts)
      when :partial, :component
        # Allow controllers to render partial/component targets into the response body
        html = view_context.render_ab(target_key, **opts)
        render html: html, layout: opts.key?(:layout) ? opts[:layout] : true
      else
        raise ArgumentError, "controller render_ab does not support #{target.type} targets"
      end
    end

    def ab_variant(target_key, expose: false)
      Identity.populate_from_controller!(self)
      AssignmentResolver.resolve(target_key, expose: expose).variant_key.to_sym
    end
  end
end
