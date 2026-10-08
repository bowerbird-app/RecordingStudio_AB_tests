# frozen_string_literal: true

module RecordingStudioAbTests
  class Target
    VALID_TYPES = %i[view partial component service].freeze

    attr_reader :key, :type, :label, :template, :partial, :control, :variants,
                :source_template, :request_variant, :error_message

    def initialize(key, type:, label: nil, template: nil, partial: nil, control: nil,
                   variants: {}, source_template: nil, request_variant: false)
      @key = key.to_sym
      @type = type.to_sym
      @label = label || @key.to_s.humanize
      @template = template
      @partial = partial
      @control = control
      @variants = normalize_variants(variants || {})
      @source_template = source_template
      @request_variant = request_variant
      @valid = true
      @error_message = nil
      validate!
    end

    def valid?
      @valid
    end

    def mark_invalid!(message)
      @valid = false
      @error_message = message
    end

    def implementation_keys
      (["control"] + @variants.keys.map(&:to_s)).uniq
    end

    def rails_variant_for(variant_key)
      return nil if variant_key.to_s == "control"

      @variants[variant_key.to_sym]&.fetch(:rails_variant, nil)
    end

    def class_name_for(variant_key)
      if variant_key.to_s == "control"
        @control
      else
        entry = @variants[variant_key.to_sym]
        return nil unless entry

        entry[:class_name]
      end
    end

    private

    def normalize_variants(variants)
      variants.each_with_object({}) do |(vk, opts), acc|
        key = vk.to_sym
        normalized =
          case opts
          when String, Symbol
            { class_name: opts.to_s }
          when Hash
            opts.transform_keys(&:to_sym)
          else
            raise InvalidTarget, "invalid variant options for #{@key}/#{key}"
          end

        normalized[:rails_variant] = :"ab_#{key}" if normalized[:rails_variant].nil? && %i[view partial].include?(@type)

        normalized[:class_name] ||= (normalized[:component] || normalized[:class])&.to_s
        acc[key] = normalized
      end
    end

    def validate!
      unless VALID_TYPES.include?(@type)
        fail_validation!("unknown target type #{@type.inspect} for #{@key}")
        return
      end

      if @variants.key?(:control)
        fail_validation!("variant key 'control' is reserved for #{@key}")
        return
      end

      case @type
      when :view
        fail_validation!("view target #{@key} requires template:") if @template.blank?
      when :partial
        fail_validation!("partial target #{@key} requires partial:") if @partial.blank?
      when :component, :service
        fail_validation!("#{@type} target #{@key} requires control:") if @control.blank?
      end
      return unless @valid

      rails_variants = @variants.values.filter_map { |v| v[:rails_variant]&.to_sym }
      return if rails_variants.size == rails_variants.uniq.size

      fail_validation!("duplicate rails_variant on target #{@key}")
    end

    def fail_validation!(message)
      raise InvalidTarget, message if raise_on_invalid?

      mark_invalid!(message)
      ActiveSupport::Notifications.instrument(
        "invalid_target.recording_studio_ab_tests",
        key: @key, message: message
      )
    end

    def raise_on_invalid?
      return true unless defined?(Rails)

      Rails.env.development? || Rails.env.test? || RecordingStudioAbTests.configuration.raise_errors
    end
  end
end
