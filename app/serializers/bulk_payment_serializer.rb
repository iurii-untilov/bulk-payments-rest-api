class BulkPaymentSerializer
  def self.call(result)
    {
      payer_firm_uuid: result.payer.uuid,
      payer_balance: Money.from_cents(result.payer_balance_cents),
      payments: result.payments.map do |payment|
        {
          id: payment[:id],
          payee_firm_uuid: payment[:payee_firm_uuid],
          amount: Money.from_cents(payment[:amount_cents]),
          description: payment[:description]
        }
      end
    }
  end
end
