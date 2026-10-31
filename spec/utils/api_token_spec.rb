require "rails_helper"

RSpec.describe ApiToken do
  it "generates unique prefixed tokens" do
    tokens = Array.new(5) { described_class.generate }

    expect(tokens.uniq.size).to eq(5)
    expect(tokens).to all(match(/\Abp_\h{64}\z/))
  end

  it "digests tokens deterministically with SHA-256" do
    expect(described_class.digest("secret")).to eq(Digest::SHA256.hexdigest("secret"))
    expect(described_class.digest("secret")).not_to eq(described_class.digest("other"))
  end
end
