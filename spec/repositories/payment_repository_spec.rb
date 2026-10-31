require "rails_helper"

RSpec.describe PaymentRepository do
  let(:payer) { create(:firm) }
  let(:payee) { create(:firm) }

  it "inserts all rows in one statement and returns them in order" do
    rows = [
      { payer_firm_id: payer.id, payee_firm_id: payee.id, amount_cents: 100, description: "first" },
      { payer_firm_id: payer.id, payee_firm_id: payee.id, amount_cents: 200, description: "second" }
    ]

    created = described_class.create_many!(rows)

    expect(created.map { |row| row.values_at("amount_cents", "description") }).to eq([ [ 100, "first" ], [ 200, "second" ] ])
    expect(created.map { |row| row["id"] }).to eq(Payment.order(:id).ids)
  end
end
