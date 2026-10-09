# frozen_string_literal: true

module Demo
  class QuoteController < ApplicationController
    skip_before_action :authenticate_user!, only: :show

    def show
      amount = params.fetch(:amount, "100").to_f
      @quote = RecordingStudioAbTests.execute(:quote_strategy, amount: amount, currency: "USD")
    end
  end
end
