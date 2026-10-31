require "rails_helper"

RSpec.describe Payments::CreateBulkPayment do
  subject(:call) { described_class.call(payer_uuid: pinecrest.uuid, payments:) }

  let!(:pinecrest) { create(:firm, name: "Pinecrest CPA Group", balance_cents: 5_000_000) }
  let!(:lopez) { create(:firm, name: "Lopez Bookkeeping", balance_cents: 50_000) }
  let!(:nair) { create(:firm, name: "Nair Tax Services", balance_cents: 200_000) }

  let(:payments) do
    [
      { amount: "6250", payee_firm_uuid: nair.uuid, description: "Overflow returns, August 2026" },
      { amount: "5800.5", payee_firm_uuid: nair.uuid, description: "Amended returns, August 2026" },
      { amount: "1200.75", payee_firm_uuid: lopez.uuid, description: "Bookkeeping cleanup, 3 clients" }
    ]
  end

  def balances
    [ pinecrest, lopez, nair ].map { |firm| firm.reload.balance_cents }
  end

  context "with the sample request from the specification" do
    it "debits the payer and credits each payee" do
      call

      expect(balances).to eq([ 3_674_875, 170_075, 1_405_050 ])
    end

    it "stores every payment" do
      expect { call }.to change(Payment, :count).by(3)

      expect(Payment.order(:id).pluck(:payer_firm_id, :payee_firm_id, :amount_cents, :description)).to eq(
        [
          [ pinecrest.id, nair.id, 625_000, "Overflow returns, August 2026" ],
          [ pinecrest.id, nair.id, 580_050, "Amended returns, August 2026" ],
          [ pinecrest.id, lopez.id, 120_075, "Bookkeeping cleanup, 3 clients" ]
        ]
      )
    end

    it "returns the created payments and the new payer balance" do
      result = call

      expect(result.payer).to eq(pinecrest)
      expect(result.payer_balance_cents).to eq(3_674_875)
      expect(result.payments.map { |p| p.values_at(:payee_firm_uuid, :amount_cents) }).to eq(
        [ [ nair.uuid, 625_000 ], [ nair.uuid, 580_050 ], [ lopez.uuid, 120_075 ] ]
      )
      expect(result.payments.map { |p| p[:id] }).to eq(Payment.order(:id).ids)
    end

    it "keeps the total amount of money in the system unchanged" do
      expect { call }.not_to change { Firm.sum(:balance_cents) }
    end
  end

  it "allows spending the exact balance" do
    pinecrest.update!(balance_cents: 1_325_125)

    call

    expect(pinecrest.reload.balance_cents).to eq(0)
  end

  context "when the payer cannot cover the total" do
    before { pinecrest.update!(balance_cents: 1_325_124) }

    it "denies the whole request with details" do
      expect { call }.to raise_error(AppError::InsufficientFunds) { |error|
        expect(error.details).to eq(required: "13251.25", available: "13251.24")
      }
    end

    it "does not change any balance or store any payment" do
      expect { call rescue nil }.not_to change { [ balances, Payment.count ] }
    end
  end

  context "when a payee does not exist" do
    let(:unknown_uuid) { SecureRandom.uuid }

    before { payments << { amount: "1", payee_firm_uuid: unknown_uuid, description: "Unknown" } }

    it "denies the whole request and reports the unknown payee" do
      expect { call }.to raise_error(AppError::UnknownPayee) { |error|
        expect(error.details).to eq(payee_firm_uuids: [ unknown_uuid ])
      }
    end

    it "does not change any balance or store any payment" do
      expect { call rescue nil }.not_to change { [ balances, Payment.count ] }
    end
  end

  it "rolls back debits and credits when inserting payments fails" do
    allow(PaymentRepository).to receive(:create_many!).and_raise(ActiveRecord::StatementInvalid, "boom")

    expect { call }.to raise_error(ActiveRecord::StatementInvalid)
    expect(balances).to eq([ 5_000_000, 50_000, 200_000 ])
  end

  it "refuses the debit when the conditional update affects no row" do
    allow(FirmRepository).to receive(:debit!).and_return(false)

    expect { call }.to raise_error(AppError::InsufficientFunds)
    expect(Payment.count).to eq(0)
  end

  it "locks all involved firms ordered by id" do
    expect(FirmRepository).to receive(:lock_by_uuids)
      .with(contain_exactly(pinecrest.uuid, nair.uuid, lopez.uuid)).and_call_original

    call
  end

  it "translates lock timeouts into a retryable service error" do
    allow(FirmRepository).to receive(:lock_by_uuids).and_raise(ActiveRecord::LockWaitTimeout)

    expect { call }.to raise_error(AppError::ServiceUnavailable)
  end

  it "translates deadlocks into a retryable service error" do
    allow(FirmRepository).to receive(:lock_by_uuids).and_raise(ActiveRecord::Deadlocked)

    expect { call }.to raise_error(AppError::ServiceUnavailable)
  end
end
