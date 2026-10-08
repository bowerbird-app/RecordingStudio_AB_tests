# frozen_string_literal: true

module Quote
  class Alternative
    def self.call(amount:, currency: "USD")
      discounted = (amount.to_f * 0.9).round(2)
      {
        variant: "b",
        amount: amount.to_f,
        currency: currency,
        total: discounted,
        label: "Promotional quote (variant B) — 10% off"
      }
    end
  end
end
