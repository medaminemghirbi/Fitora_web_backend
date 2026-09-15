require "rails_helper"

RSpec.describe SubscriptionPrice do
  describe ".for" do
    it "creates the reference (TND) tier-1 row at the default price" do
      row = described_class.for("TND", company_limit: 1)
      expect(row.monthly_cents).to eq(described_class::DEFAULT_MONTHLY_CENTS)
    end

    it "seeds a newly-seen currency's tier from the same tier's TND reference price" do
      described_class.for("TND", company_limit: 1).update!(monthly_cents: 21_000)

      expect(described_class.for("EUR", company_limit: 1).monthly_cents).to eq(21_000)
    end

    it "seeds a tier that's never been priced anywhere from a multiplier off the default" do
      row = described_class.for("TND", company_limit: 3)
      expect(row.monthly_cents).to eq((described_class::DEFAULT_MONTHLY_CENTS * described_class::DEFAULT_MULTIPLIERS[3]).round)
    end

    it "defaults a blank currency to the reference" do
      expect(described_class.for(nil, company_limit: 1).currency).to eq("TND")
    end

    it "treats a nil company_limit as the unlimited tier" do
      expect(described_class.for("TND", company_limit: nil).company_limit).to eq(described_class::UNLIMITED)
    end

    it "keeps each tier of a currency priced independently" do
      described_class.for("TND", company_limit: 1).update!(monthly_cents: 10_000)
      described_class.for("TND", company_limit: 3).update!(monthly_cents: 20_000)

      expect(described_class.for("TND", company_limit: 1).monthly_cents).to eq(10_000)
      expect(described_class.for("TND", company_limit: 3).monthly_cents).to eq(20_000)
    end
  end

  it "validates the currency, the tier, and a non-negative price" do
    expect(described_class.new(currency: "XXX", company_limit: 1, monthly_cents: 100)).to be_invalid
    expect(described_class.new(currency: "TND", company_limit: 2, monthly_cents: 100)).to be_invalid
    expect(described_class.new(currency: "TND", company_limit: 1, monthly_cents: -1)).to be_invalid
  end

  it "rejects a duplicate currency+tier pair" do
    create(:subscription_price, currency: "EUR", company_limit: 1)
    duplicate = build(:subscription_price, currency: "EUR", company_limit: 1)

    expect(duplicate).not_to be_valid
  end

  it "allows the same currency at a different tier" do
    create(:subscription_price, currency: "EUR", company_limit: 1)
    other_tier = build(:subscription_price, currency: "EUR", company_limit: 3)

    expect(other_tier).to be_valid
  end

  describe "#unlimited?" do
    it "is true only for the UNLIMITED sentinel tier" do
      expect(described_class.new(company_limit: SubscriptionPrice::UNLIMITED)).to be_unlimited
      expect(described_class.new(company_limit: 1)).not_to be_unlimited
    end
  end
end
