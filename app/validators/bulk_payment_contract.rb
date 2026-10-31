class BulkPaymentContract < Dry::Validation::Contract
  UUID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  MAX_PAYMENTS = 1000
  MAX_DESCRIPTION_LENGTH = 1000

  json do
    required(:payer_firm_uuid).filled(:string, format?: UUID_FORMAT)
    required(:payments).value(:array, min_size?: 1, max_size?: MAX_PAYMENTS).each do
      hash do
        required(:amount).filled(:string, format?: Money::FORMAT)
        required(:payee_firm_uuid).filled(:string, format?: UUID_FORMAT)
        required(:description).filled(:string, max_size?: MAX_DESCRIPTION_LENGTH)
      end
    end
  end

  rule(:payments).each do |index:|
    cents = Money.to_cents(value[:amount])
    key([ :payments, index, :amount ]).failure("must be greater than 0") unless cents.positive?
    key([ :payments, index, :amount ]).failure("must not exceed #{Money.from_cents(Money::MAX_CENTS)}") if cents > Money::MAX_CENTS
    key([ :payments, index, :description ]).failure("must not be blank") if value[:description].strip.empty?
    if value[:payee_firm_uuid] == values[:payer_firm_uuid]
      key([ :payments, index, :payee_firm_uuid ]).failure("must differ from payer_firm_uuid")
    end
  end
end
