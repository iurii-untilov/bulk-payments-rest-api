require "rails_helper"

RSpec.describe Auth::AuthenticateApiKey do
  let(:firm) { create(:firm) }
  let(:token) { ApiToken.generate }

  before { create(:api_key, firm:, token:) }

  it "returns the firm that owns an active key" do
    expect(described_class.call(token)).to eq(firm)
  end

  it "rejects a missing token" do
    expect { described_class.call(nil) }.to raise_error(AppError::Unauthorized)
    expect { described_class.call("") }.to raise_error(AppError::Unauthorized)
  end

  it "rejects an unknown token" do
    expect { described_class.call("bp_unknown") }.to raise_error(AppError::Unauthorized)
  end

  it "rejects a revoked token" do
    ApiKey.update_all(revoked_at: Time.current)

    expect { described_class.call(token) }.to raise_error(AppError::Unauthorized)
  end
end
