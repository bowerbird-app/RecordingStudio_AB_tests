# frozen_string_literal: true

module RecordingStudioAbTests
  module Adapters
    module Component
      module_function

      def render(view, target, **)
        resolution = AssignmentResolver.resolve(target.key, expose: true)
        class_name =
          if resolution.variant_key.to_s == "control" || resolution.implementation_key.to_s == "control"
            target.control
          else
            target.class_name_for(resolution.variant_key) || target.control
          end

        klass = class_name.constantize
        view.render(klass.new(**))
      end
    end
  end
end
