require "rails_helper"

RSpec.describe Idempotency::Execute do
  let(:firm) { create(:firm) }
  let(:response) { described_class::Response.new(status: 201, body: { "ok" => true }) }
  let(:calls) { [] }

  def execute(key: "key-1", digest: "digest-1", &block)
    block ||= -> { calls << :executed; response }
    described_class.call(firm_id: firm.id, key:, request_digest: digest, &block)
  end

  it "executes the block without storing anything when no key is given" do
    expect(execute(key: nil)).to eq(response)
    expect(calls).to eq([ :executed ])
    expect(IdempotencyKey.count).to eq(0)
  end

  it "stores the response for a new key" do
    execute

    record = IdempotencyKey.last
    expect(record).to have_attributes(firm_id: firm.id, key: "key-1", request_digest: "digest-1",
                                      response_status: 201, response_body: { "ok" => true })
  end

  it "replays the stored response without executing the block again" do
    execute
    replayed = execute

    expect(calls).to eq([ :executed ])
    expect(replayed).to have_attributes(status: 201, body: { "ok" => true })
  end

  it "rejects a reused key with a different request" do
    execute

    expect { execute(digest: "digest-2") }.to raise_error(AppError::IdempotencyConflict)
    expect(calls).to eq([ :executed ])
  end

  it "scopes keys per firm" do
    execute
    other_firm = create(:firm)
    described_class.call(firm_id: other_firm.id, key: "key-1", request_digest: "digest-1") { calls << :other; response }

    expect(calls).to eq([ :executed, :other ])
  end

  it "does not store the key when the block fails, so the request can be retried" do
    expect { execute { raise AppError::InsufficientFunds } }.to raise_error(AppError::InsufficientFunds)
    expect(IdempotencyKey.count).to eq(0)

    expect(execute).to eq(response)
  end

  it "rolls back the block's writes when storing the key fails" do
    allow(IdempotencyKeyRepository).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "boom")

    expect { execute { firm.update!(balance_cents: 1); response } }.to raise_error(ActiveRecord::StatementInvalid)
    expect(firm.reload.balance_cents).to eq(0)
  end

  it "replays the winner's response when a concurrent request stored the same key first" do
    IdempotencyKey.create!(firm_id: firm.id, key: "key-1", request_digest: "digest-1",
                           response_status: 201, response_body: { "winner" => true })
    lookups = 0
    allow(IdempotencyKeyRepository).to receive(:find).and_wrap_original do |original, **args|
      (lookups += 1) == 1 ? nil : original.call(**args)
    end

    result = execute

    expect(result.body).to eq("winner" => true)
    expect(IdempotencyKey.count).to eq(1)
  end
end
