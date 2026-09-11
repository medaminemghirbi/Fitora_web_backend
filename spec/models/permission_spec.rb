require "rails_helper"

RSpec.describe Permission do
  describe ".valid?" do
    it "accepts a catalogue key and rejects anything else" do
      expect(Permission.valid?("clients")).to be true
      expect(Permission.valid?("not_a_real_permission")).to be false
    end

    it "accepts symbols as well as strings" do
      expect(Permission.valid?(:payments)).to be true
    end
  end

  describe ".sanitize" do
    it "keeps only recognised keys, de-duplicated, in catalogue order" do
      expect(Permission.sanitize(%w[payments bogus clients payments])).to eq(%w[clients payments])
    end

    it "returns an empty array for blank input" do
      expect(Permission.sanitize(nil)).to eq([])
    end
  end

  it "exposes ALL as the catalogue's frozen key list" do
    expect(Permission::ALL).to eq(Permission::CATALOG.keys)
    expect(Permission::ALL).to be_frozen
  end
end
