# frozen_string_literal: true

module Quote
  class Standard
    def self.call(amount:, currency: "USD")
      {
        variant: "control",
        amount: amount.to_f,
        currency: currency,
        total: amount.to_f,
        label: "Standard quote (control)"
      }
    end
  end
end
