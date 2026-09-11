require "rails_helper"

RSpec.describe Contracts::Cancel do
  it "cancels the contract's current period" do
    contract = create(:contract, status: :active)

    result = described_class.call(contract: contract)

    expect(result.success?).to be true
    expect(result.error).to be_nil
    expect(contract.reload).to be_cancelled
  end

  it "cancels a pending contract's current period too" do
    contract = create(:contract, status: :pending)

    result = described_class.call(contract: contract)

    expect(result.success?).to be true
    expect(contract.reload).to be_cancelled
  end

  it "rejects cancelling an already cancelled contract" do
    contract = create(:contract, status: :cancelled)

    result = described_class.call(contract: contract)

    expect(result.success?).to be false
    expect(result.error).to eq("This contract is already cancelled.")
  end
end
