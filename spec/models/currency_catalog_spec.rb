require "rails_helper"

RSpec.describe CurrencyCatalog do
  it "exposes a stable option list of code + symbol + name" do
    opts = described_class.options
    expect(opts).to all(include(:code, :symbol, :name))
    expect(opts.map { |o| o[:code] }).to include("TND", "EUR", "USD", "MAD")
    expect(described_class.options.find { |o| o[:code] == "TND" }[:symbol]).to eq("DT")
  end

  it "resolves a symbol, falling back to the raw code" do
    expect(described_class.symbol("EUR")).to eq("€")
    expect(described_class.symbol("ZZZ")).to eq("ZZZ")
  end

  it "knows which codes are valid" do
    expect(described_class).to be_valid("TND")
    expect(described_class).not_to be_valid("BTC")
  end
end
