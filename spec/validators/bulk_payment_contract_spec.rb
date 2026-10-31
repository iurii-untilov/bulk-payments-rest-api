require "rails_helper"

RSpec.describe BulkPaymentContract do
  subject(:result) { described_class.new.call(input) }

  let(:payer_uuid) { "3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41" }
  let(:payee_uuid) { "8b2e4c71-0d3a-4f6e-b1c9-5a7d2e9f4c10" }
  let(:payment) { { "amount" => "1200.75", "payee_firm_uuid" => payee_uuid, "description" => "Bookkeeping cleanup" } }
  let(:input) { { "payer_firm_uuid" => payer_uuid, "payments" => [ payment ] } }

  def errors_at(*path)
    result.errors.to_h.dig(*path)
  end

  it "accepts a valid request and returns symbolized output" do
    expect(result).to be_success
    expect(result.to_h).to eq(
      payer_firm_uuid: payer_uuid,
      payments: [ { amount: "1200.75", payee_firm_uuid: payee_uuid, description: "Bookkeeping cleanup" } ]
    )
  end

  it "drops unknown attributes" do
    input["extra"] = "ignored"
    payment["note"] = "ignored"

    expect(result.to_h.keys).to contain_exactly(:payer_firm_uuid, :payments)
    expect(result.to_h[:payments].first.keys).to contain_exactly(:amount, :payee_firm_uuid, :description)
  end

  it "requires payer_firm_uuid and payments" do
    input.clear

    expect(errors_at(:payer_firm_uuid)).to be_present
    expect(errors_at(:payments)).to be_present
  end

  it "rejects a malformed or uppercase payer uuid" do
    input["payer_firm_uuid"] = "not-a-uuid"
    expect(errors_at(:payer_firm_uuid)).to be_present

    input["payer_firm_uuid"] = payer_uuid.upcase
    expect(described_class.new.call(input).errors.to_h[:payer_firm_uuid]).to be_present
  end

  it "rejects an empty payments list" do
    input["payments"] = []

    expect(errors_at(:payments)).to be_present
  end

  it "rejects more than the maximum number of payments" do
    input["payments"] = Array.new(described_class::MAX_PAYMENTS + 1) { payment }

    expect(errors_at(:payments)).to be_present
  end

  it "rejects payments that are not objects" do
    input["payments"] = [ "100" ]

    expect(result).to be_failure
  end

  it "rejects numeric amounts" do
    payment["amount"] = 1200.75

    expect(errors_at(:payments, 0, :amount)).to be_present
  end

  [ "-5", "1.234", "1e3", "abc", "" ].each do |amount|
    it "rejects amount #{amount.inspect}" do
      payment["amount"] = amount

      expect(errors_at(:payments, 0, :amount)).to be_present
    end
  end

  [ "0", "0.00" ].each do |amount|
    it "rejects zero amount #{amount.inspect}" do
      payment["amount"] = amount

      expect(errors_at(:payments, 0, :amount)).to include("must be greater than 0")
    end
  end

  it "rejects amounts above the maximum" do
    payment["amount"] = "10000000000000.01"

    expect(errors_at(:payments, 0, :amount)).to be_present
  end

  it "rejects missing, blank and too long descriptions" do
    [ nil, "", "   ", "x" * (described_class::MAX_DESCRIPTION_LENGTH + 1) ].each do |description|
      payment["description"] = description

      expect(described_class.new.call(input).errors.to_h.dig(:payments, 0, :description)).to be_present
    end
  end

  it "rejects a payment to the payer itself" do
    payment["payee_firm_uuid"] = payer_uuid

    expect(errors_at(:payments, 0, :payee_firm_uuid)).to include("must differ from payer_firm_uuid")
  end

  it "reports errors per payment index" do
    input["payments"] = [ payment, payment.merge("amount" => "bad") ]

    expect(errors_at(:payments, 0)).to be_nil
    expect(errors_at(:payments, 1, :amount)).to be_present
  end
end
