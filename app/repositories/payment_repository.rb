class PaymentRepository
  RETURNING = %w[id payer_firm_id payee_firm_id amount_cents description].freeze

  def self.create_many!(rows)
    Payment.insert_all!(rows, returning: RETURNING).to_a
  end
end
