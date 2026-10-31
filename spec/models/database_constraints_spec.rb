require "rails_helper"

RSpec.describe "Database constraints" do
  let(:payer) { create(:firm) }
  let(:payee) { create(:firm) }

  it "forbids a negative firm balance" do
    expect { payer.update_column(:balance_cents, -1) }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "requires unique firm uuids" do
    expect { create(:firm, uuid: payer.uuid) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "forbids non-positive payment amounts" do
    expect { Payment.create!(payer_firm: payer, payee_firm: payee, amount_cents: 0, description: "x") }
      .to raise_error(ActiveRecord::CheckViolation)
  end

  it "forbids payments from a firm to itself" do
    expect { Payment.create!(payer_firm: payer, payee_firm: payer, amount_cents: 1, description: "x") }
      .to raise_error(ActiveRecord::CheckViolation)
  end

  it "requires payments to reference existing firms" do
    expect { Payment.insert_all!([ { payer_firm_id: payer.id, payee_firm_id: 0, amount_cents: 1, description: "x" } ]) }
      .to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it "requires unique idempotency keys per firm" do
    attrs = { firm_id: payer.id, key: "k", request_digest: "d", response_status: 201, response_body: {} }
    IdempotencyKey.create!(attrs)

    expect { IdempotencyKey.create!(attrs) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
