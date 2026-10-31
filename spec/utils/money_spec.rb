require "rails_helper"

RSpec.describe Money do
  describe ".to_cents" do
    {
      "300" => 30_000,
      "1200.75" => 120_075,
      "5800.5" => 580_050,
      "0.01" => 1,
      "0" => 0,
      "007.10" => 710,
      "10000000000000" => 1_000_000_000_000_000
    }.each do |amount, cents|
      it "converts #{amount.inspect} to #{cents} cents" do
        expect(described_class.to_cents(amount)).to eq(cents)
      end
    end

    [ "-1", "1.234", "1e3", " 1", "1 ", "1,00", ".5", "1.", "abc", "", "0x10", "1.2.3" ].each do |amount|
      it "rejects #{amount.inspect}" do
        expect { described_class.to_cents(amount) }.to raise_error(ArgumentError)
      end
    end

    it "rejects non-string amounts" do
      expect { described_class.to_cents(12.5) }.to raise_error(ArgumentError)
      expect { described_class.to_cents(nil) }.to raise_error(ArgumentError)
    end

    it "does not lose precision on values that are inexact as floats" do
      expect(described_class.to_cents("0.29")).to eq(29)
      expect(described_class.to_cents("1.15")).to eq(115)
    end
  end

  describe ".from_cents" do
    it "formats cents as a dollar string with two decimals" do
      expect(described_class.from_cents(3_674_875)).to eq("36748.75")
      expect(described_class.from_cents(5)).to eq("0.05")
      expect(described_class.from_cents(0)).to eq("0.00")
      expect(described_class.from_cents(170_075)).to eq("1700.75")
    end
  end
end
