# frozen_string_literal: true

module Demo
  class HeroControlComponent < ViewComponent::Base
    def initialize(title:)
      @title = title
    end

    def call
      content_tag(:div, id: "hero-variant", data: { variant: "control" }) do
        content_tag(:h2, @title) + content_tag(:p, "Control hero component")
      end
    end
  end
end
