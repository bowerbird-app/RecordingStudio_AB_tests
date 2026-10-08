# frozen_string_literal: true

module Demo
  class HeroVariantBComponent < ViewComponent::Base
    def initialize(title:)
      @title = title
    end

    def call
      content_tag(:div, id: "hero-variant", data: { variant: "b" }) do
        content_tag(:h2, "#{@title} (B)") + content_tag(:p, "Experimental hero component")
      end
    end
  end
end
