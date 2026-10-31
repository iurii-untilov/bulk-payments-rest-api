require "rails_helper"

RSpec.describe "POST /api/v1/bulk_payments" do
  let!(:pinecrest) { create(:firm, name: "Pinecrest CPA Group", balance_cents: 5_000_000, uuid: "3f1c9a2e-7b4d-4c1e-9a55-2d8e6f0b7c41") }
  let!(:lopez) { create(:firm, name: "Lopez Bookkeeping", balance_cents: 50_000, uuid: "8b2e4c71-0d3a-4f6e-b1c9-5a7d2e9f4c10") }
  let!(:nair) { create(:firm, name: "Nair Tax Services", balance_cents: 200_000, uuid: "e5f18b3c-2a9d-4c07-8e6b-1d4a7f9c3b25") }
  let(:token) { ApiToken.generate }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }
  let(:body) do
    {
      payer_firm_uuid: pinecrest.uuid,
      payments: [
        { amount: "6250", payee_firm_uuid: nair.uuid, description: "Overflow returns, August 2026" },
        { amount: "5800.5", payee_firm_uuid: nair.uuid, description: "Amended returns, August 2026" },
        { amount: "1200.75", payee_firm_uuid: lopez.uuid, description: "Bookkeeping cleanup, 3 clients" }
      ]
    }
  end

  before { create(:api_key, firm: pinecrest, token:) }

  def post_payments(payload = body.to_json, extra_headers = {})
    post "/api/v1/bulk_payments", params: payload, headers: headers.merge(extra_headers)
  end

  def json
    response.parsed_body
  end

  def balances
    [ pinecrest, lopez, nair ].map { |firm| firm.reload.balance_cents }
  end

  context "with the sample request" do
    it "returns 201 with the created payments and updates balances" do
      post_payments

      expect(response).to have_http_status(:created)
      expect(json["payer_firm_uuid"]).to eq(pinecrest.uuid)
      expect(json["payer_balance"]).to eq("36748.75")
      expect(json["payments"].map { |p| p.slice("payee_firm_uuid", "amount", "description") }).to eq(
        [
          { "payee_firm_uuid" => nair.uuid, "amount" => "6250.00", "description" => "Overflow returns, August 2026" },
          { "payee_firm_uuid" => nair.uuid, "amount" => "5800.50", "description" => "Amended returns, August 2026" },
          { "payee_firm_uuid" => lopez.uuid, "amount" => "1200.75", "description" => "Bookkeeping cleanup, 3 clients" }
        ]
      )
      expect(json["payments"].map { |p| p["id"] }).to eq(Payment.order(:id).ids)
      expect(balances).to eq([ 3_674_875, 170_075, 1_405_050 ])
    end
  end

  context "when funds are insufficient" do
    before { pinecrest.update!(balance_cents: 100) }

    it "returns 422 and changes nothing" do
      expect { post_payments }.not_to change { [ Payment.count, balances ] }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include("code" => "insufficient_funds",
                                       "details" => { "required" => "13251.25", "available" => "1.00" })
    end
  end

  it "returns 422 when a payee does not exist" do
    body[:payments] << { amount: "1", payee_firm_uuid: "00000000-0000-4000-8000-000000000000", description: "x" }

    expect { post_payments }.not_to change(Payment, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["code"]).to eq("unknown_payee")
  end

  describe "authentication and authorization" do
    it "returns 401 without a token" do
      post_payments(body.to_json, "Authorization" => nil)

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      expect(json["error"]["code"]).to eq("unauthorized")
    end

    it "returns 401 with an invalid token" do
      post_payments(body.to_json, "Authorization" => "Bearer bp_invalid")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with a revoked token" do
      ApiKey.update_all(revoked_at: Time.current)
      post_payments

      expect(response).to have_http_status(:unauthorized)
    end

    it "authenticates before parsing the body" do
      post_payments("{not json", "Authorization" => nil)

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 when the token belongs to another firm" do
      other_token = ApiToken.generate
      create(:api_key, firm: lopez, token: other_token)

      expect { post_payments(body.to_json, "Authorization" => "Bearer #{other_token}") }.not_to change { balances }

      expect(response).to have_http_status(:forbidden)
      expect(json["error"]["code"]).to eq("forbidden")
    end
  end

  describe "validation" do
    it "returns 400 for malformed JSON" do
      post_payments("{not json")

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]["code"]).to eq("malformed_request")
    end

    it "returns 400 with field details for an invalid payload" do
      body[:payments][1][:amount] = "-5"
      body[:payments][2].delete(:description)

      expect { post_payments }.not_to change(Payment, :count)

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]["code"]).to eq("validation_failed")
      expect(json["error"]["details"]["payments"].keys).to contain_exactly("1", "2")
    end

    it "returns 400 for a JSON array body" do
      post_payments("[]")

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 for an invalid Idempotency-Key" do
      post_payments(body.to_json, "Idempotency-Key" => "x" * 256)

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]["details"]).to have_key("idempotency_key")
    end
  end

  describe "idempotency" do
    it "processes a retried request only once and replays the response" do
      post_payments(body.to_json, "Idempotency-Key" => "retry-1")
      first = json

      expect { post_payments(body.to_json, "Idempotency-Key" => "retry-1") }.not_to change { [ Payment.count, balances ] }

      expect(response).to have_http_status(:created)
      expect(json).to eq(first)
    end

    it "returns 409 when the key is reused with a different payload" do
      post_payments(body.to_json, "Idempotency-Key" => "retry-1")
      body[:payments].pop

      expect { post_payments(body.to_json, "Idempotency-Key" => "retry-1") }.not_to change { [ Payment.count, balances ] }

      expect(response).to have_http_status(:conflict)
      expect(json["error"]["code"]).to eq("idempotency_key_conflict")
    end

    it "processes requests without a key independently" do
      post_payments
      post_payments

      expect(Payment.count).to eq(6)
    end
  end

  describe "server errors" do
    it "returns 500 without leaking details and logs the exception" do
      allow(Payments::CreateBulkPayment).to receive(:call).and_raise(RuntimeError, "secret internal failure")
      allow(Rails.logger).to receive(:error)

      post_payments

      expect(response).to have_http_status(:internal_server_error)
      expect(json["error"]).to include("code" => "internal_error", "message" => "Internal server error")
      expect(json["error"]["request_id"]).to be_present
      expect(response.body).not_to include("secret internal failure")
      expect(Rails.logger).to have_received(:error).with(/secret internal failure/)
    end

    it "returns 503 when locks cannot be acquired in time" do
      allow(FirmRepository).to receive(:lock_by_uuids).and_raise(ActiveRecord::LockWaitTimeout)

      post_payments

      expect(response).to have_http_status(:service_unavailable)
      expect(json["error"]["code"]).to eq("service_unavailable")
    end
  end
end
