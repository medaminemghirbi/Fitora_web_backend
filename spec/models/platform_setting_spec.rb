require "rails_helper"

RSpec.describe PlatformSetting do
  describe ".current" do
    it "creates the singleton on first access and reuses it after" do
      first = described_class.current
      expect(described_class.current.id).to eq(first.id)
      expect(described_class.count).to eq(1)
    end

    it "defaults the annual discount to 10%" do
      expect(described_class.current.annual_discount_percent).to eq(10)
    end
  end

  it "keeps the discount between 0 and 100" do
    expect(described_class.new(annual_discount_percent: -1)).to be_invalid
    expect(described_class.new(annual_discount_percent: 101)).to be_invalid
    expect(described_class.new(annual_discount_percent: 0)).to be_valid
  end
end
