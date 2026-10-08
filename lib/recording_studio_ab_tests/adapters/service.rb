# frozen_string_literal: true

module RecordingStudioAbTests
  module Adapters
    # Selects the implementation class before execution and calls `.call(**kwargs)`.
    # Contract: every implementation responds to `.call` with the same keywords.
    # Authorization and validation stay in the host. No method interception.
    module Service
      module_function

      def execute(target, **kwargs)
        resolution = AssignmentResolver.resolve(target.key, expose: true)
        class_name = class_name_for(target, resolution)
        raise ArgumentError, "service target #{target.key} has no class for #{resolution.variant_key}" if class_name.blank?

        klass = class_name.constantize
        klass.call(**kwargs)
      end

      def class_name_for(target, resolution)
        if resolution.variant_key.to_s == "control" || resolution.implementation_key.to_s == "control"
          target.control
        else
          target.class_name_for(resolution.variant_key) || target.control
        end
      end
      module_function :class_name_for
    end
  end
end
