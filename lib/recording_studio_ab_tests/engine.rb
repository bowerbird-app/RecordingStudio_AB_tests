# frozen_string_literal: true

module RecordingStudioAbTests
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAbTests

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioAbTests.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_ab_tests_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_ab_tests_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    initializer "recording_studio_ab_tests.middleware" do |app|
      app.middleware.use RecordingStudioAbTests::RequestContext
    end

    initializer "recording_studio_ab_tests.helpers" do
      ActiveSupport.on_load(:action_view) do
        include RecordingStudioAbTests::ViewHelper
      end
      ActiveSupport.on_load(:action_controller_base) do
        include RecordingStudioAbTests::ControllerHelper
      end
    end

    initializer "recording_studio_ab_tests.before_initialize", before: "recording_studio_ab_tests.load_config" do |_app|
      RecordingStudioAbTests.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_ab_tests.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_ab_tests)
          rescue StandardError
            nil
          end
          RecordingStudioAbTests.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          # ignore load errors; host app can provide initializer overrides
        end
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_ab_tests)
        xcfg = app.config.x.recording_studio_ab_tests
        if xcfg.respond_to?(:to_h)
          RecordingStudioAbTests.configuration.merge!(xcfg.to_h)
        else
          begin
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioAbTests.configuration.merge!(hash) if hash&.any?
          rescue StandardError
            # ignore
          end
        end
      end

      RecordingStudioAbTests.configuration.hooks.run(:on_configuration, RecordingStudioAbTests.configuration)
    end

    initializer "recording_studio_ab_tests.after_initialize", after: "recording_studio_ab_tests.load_config" do |_app|
      RecordingStudioAbTests.configuration.hooks.run(:after_initialize, self)
    end

    # Host-opt-in model extensions via RecordingStudio::Hooks (never used to patch other gems).
    initializer "recording_studio_ab_tests.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioAbTests::Engine.apply_model_extensions(model)
        end
      end
    end

    # Host-opt-in controller extensions via hooks only. Do not use this to touch other gems' controllers.
    initializer "recording_studio_ab_tests.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioAbTests::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
