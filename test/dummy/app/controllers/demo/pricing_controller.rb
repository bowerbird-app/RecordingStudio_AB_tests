# frozen_string_literal: true

module Demo
  class PricingController < ApplicationController
    def show
      render_ab :pricing_page
    end

    # Re-render on POST so eligibility can honour an existing assignment without creating one.
    def create
      render_ab :pricing_page
    end
  end
end
