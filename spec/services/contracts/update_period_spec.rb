require "rails_helper"

RSpec.describe Contracts::UpdatePeriod do
  it "updates the start date and re-derives the expiry from the plan's billing period" do
    contract_type = create(:contract_type, billing_period: :monthly)
    contract = create(:contract, contract_type: contract_type, status: :active)
    new_start = 3.days.from_now.to_date

    result = described_class.call(contract: contract, starts_on: new_start)

    expect(result.success?).to be true
    expect(result.error).to be_nil
    period = contract.reload.current_period
    expect(period.starts_at.to_date).to eq(new_start)
    expect(period.expires_at.to_date).to eq(new_start + 30.days)
  end

  it "updates the expiry date directly when given" do
    contract = create(:contract, status: :active)
    new_expiry = 60.days.from_now.to_date

    result = described_class.call(contract: contract, expires_on: new_expiry)

    expect(result.success?).to be true
    expect(contract.reload.current_period.expires_at.to_date).to eq(new_expiry)
  end

  it "updates the discount while the period is unpaid" do
    contract = create(:contract, status: :active, payment_status: :unpaid)

    result = described_class.call(contract: contract, discount: 15)

    expect(result.success?).to be true
    expect(contract.reload.current_period.discount).to eq(15.0)
  end

  it "rejects a discount change once the period is paid" do
    contract = create(:contract, status: :active, payment_status: :paid)

    result = described_class.call(contract: contract, discount: 15)

    expect(result.success?).to be false
    expect(result.error).to eq("Discount can only change while the subscription is unpaid")
    expect(contract.reload.current_period.discount).to eq(0.0)
  end

  it "rejects editing when the contract has no period at all" do
    contract = create(:contract)
    contract.contract_periods.destroy_all

    result = described_class.call(contract: contract, expires_on: 10.days.from_now.to_date)

    expect(result.success?).to be false
    expect(result.error).to eq("No active subscription to edit")
  end

  it "rejects editing an expired period" do
    contract = create(:contract, status: :expired)

    result = described_class.call(contract: contract, expires_on: 10.days.from_now.to_date)

    expect(result.success?).to be false
    expect(result.error).to eq("This subscription can no longer be edited")
  end

  it "rejects editing a cancelled period" do
    contract = create(:contract, status: :cancelled)

    result = described_class.call(contract: contract, expires_on: 10.days.from_now.to_date)

    expect(result.success?).to be false
    expect(result.error).to eq("This subscription can no longer be edited")
  end

  it "allows editing while the period is pending" do
    contract = create(:contract, status: :pending)

    result = described_class.call(contract: contract, expires_on: 20.days.from_now.to_date)

    expect(result.success?).to be true
  end

  it "returns a friendly error for an unparseable date" do
    contract = create(:contract, status: :active)

    result = described_class.call(contract: contract, starts_on: "not-a-date")

    expect(result.success?).to be false
    expect(result.error).to eq("Invalid date")
  end

  it "returns the record's validation error when the update is invalid" do
    contract = create(:contract, status: :active, payment_status: :unpaid)

    result = described_class.call(contract: contract, discount: -5)

    expect(result.success?).to be false
    expect(result.error).to be_present
    expect(contract.reload.current_period.discount).to eq(0.0)
  end
end
