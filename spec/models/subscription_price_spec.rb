require "rails_helper"

RSpec.describe SubscriptionPrice do
  describe ".for" do
    it "creates the reference (TND) row at the default price" do
      row = described_class.for("TND")
      expect(row.monthly_cents).to eq(described_class::DEFAULT_MONTHLY_CENTS)
    end

    it "seeds a newly-seen currency from the TND reference price" do
      described_class.for("TND").update!(monthly_cents: 21_000)

      expect(described_class.for("EUR").monthly_cents).to eq(21_000)
    end

    it "defaults a blank currency to the reference" do
      expect(described_class.for(nil).currency).to eq("TND")
    end
  end

  it "validates the currency and a non-negative price" do
    expect(described_class.new(currency: "XXX", monthly_cents: 100)).to be_invalid
    expect(described_class.new(currency: "TND", monthly_cents: -1)).to be_invalid
  end
end
