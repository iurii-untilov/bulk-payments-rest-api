require "rails_helper"

RSpec.describe FirmRepository do
  let!(:firm_a) { create(:firm, balance_cents: 1_000) }
  let!(:firm_b) { create(:firm, balance_cents: 500) }

  describe ".lock_by_uuids" do
    it "returns the matching firms ordered by id, ignoring unknown and duplicate uuids" do
      firms = described_class.lock_by_uuids([ firm_b.uuid, SecureRandom.uuid, firm_a.uuid, firm_b.uuid ])

      expect(firms).to eq([ firm_a, firm_b ])
    end

    it "locks the rows with SELECT ... ORDER BY id FOR UPDATE" do
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        described_class.lock_by_uuids([ firm_a.uuid ])
      end

      expect(queries.last).to match(/ORDER BY "firms"\."id" ASC FOR UPDATE/)
    end
  end

  describe ".debit!" do
    it "subtracts the amount when the balance covers it" do
      expect(described_class.debit!(firm_a.id, 1_000)).to be(true)
      expect(firm_a.reload.balance_cents).to eq(0)
    end

    it "does nothing and returns false when the balance is insufficient" do
      expect(described_class.debit!(firm_a.id, 1_001)).to be(false)
      expect(firm_a.reload.balance_cents).to eq(1_000)
    end
  end

  describe ".credit!" do
    it "adds the amount" do
      expect(described_class.credit!(firm_b.id, 250)).to be(true)
      expect(firm_b.reload.balance_cents).to eq(750)
    end
  end
end
