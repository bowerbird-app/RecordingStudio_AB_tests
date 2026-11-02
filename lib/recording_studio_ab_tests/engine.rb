# frozen_string_literal: true

module RecordingStudioAbTests
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioAbTests

    rake_tasks do
      load File.expand_path("../tasks/recording_studio_ab_tests.rake", __dir__)
    end

    class << self
      def apply_model_extensions(target)
        return unless target

        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        return unless target

        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      def yaml_configuration(app)
        return unless app.respond_to?(:config_for)

        app.config_for(:recording_studio_ab_tests)
      rescue Errno::ENOENT, ActiveSupport::ConfigurationFile::FormatError
        nil
      rescue RuntimeError => e
        raise unless missing_or_invalid_yaml_config?(e)

        nil
      end

      def x_configuration(app)
        return unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_ab_tests)

        app.config.x.recording_studio_ab_tests
      end

      def missing_or_invalid_yaml_config?(error)
        message = error.message.to_s
        message.include?("No such file") || message.include?("YAML syntax error")
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

    initializer "recording_studio_ab_tests.register_shipped_english",
                before: "recording_studio.load_shipped_english" do
      RecordingStudio::Translation.register_shipped_english(
        root.join("config/locales/en.yml")
      )
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

    # Soft-detect Admin (PR3 owns definitions). Never hard-depend on recording_studio_admin.
    initializer "recording_studio_ab_tests.register_admin" do
      config.to_prepare do
        next unless defined?(RecordingStudioAdmin)

        require "recording_studio_ab_tests/admin"
        RecordingStudioAbTests::Admin.register!
      end
    end

    initializer "recording_studio_ab_tests.before_initialize", before: "recording_studio_ab_tests.load_config" do |_app|
      RecordingStudioAbTests.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_ab_tests.load_config" do |app|
      yaml = RecordingStudioAbTests::Engine.yaml_configuration(app)
      RecordingStudioAbTests.configuration.merge!(yaml) if yaml.respond_to?(:each)

      xcfg = RecordingStudioAbTests::Engine.x_configuration(app)
      if xcfg.respond_to?(:to_h)
        RecordingStudioAbTests.configuration.merge!(xcfg.to_h)
      elsif xcfg.respond_to?(:each_pair)
        hash = {}
        xcfg.each_pair { |k, v| hash[k] = v }
        RecordingStudioAbTests.configuration.merge!(hash) if hash.any?
      end

      RecordingStudioAbTests.configuration.hooks.run(:on_configuration, RecordingStudioAbTests.configuration)
    end

    initializer "recording_studio_ab_tests.after_initialize", after: "recording_studio_ab_tests.load_config" do |_app|
      RecordingStudioAbTests.configuration.hooks.run(:after_initialize, self)
    end

    # Built-in user_registered + notification subscriptions (reload-safe).
    initializer "recording_studio_ab_tests.event_subscriptions" do
      config.to_prepare do
        RecordingStudioAbTests::EventSubscriptions.install!
      end
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
