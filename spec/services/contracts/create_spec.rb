require "rails_helper"

RSpec.describe Contracts::Create do
  it "creates an active contract with expires_at derived from the plan's duration" do
    plan = create(:contract_type, price: 89)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    starts_on = Date.current
    result = described_class.call(client: client, contract_type: plan, created_by: staff, starts_on: starts_on)

    expect(result.success?).to be true
    expect(result.contract).to be_active
    expect(result.contract.expires_at.to_date).to eq(starts_on + 30.days)
    expect(result.contract.final_price).to eq(89)
  end

  it "applies a discount to the final price" do
    plan = create(:contract_type, price: 100)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    result = described_class.call(client: client, contract_type: plan, created_by: staff, discount: 20)

    expect(result.contract.final_price).to eq(80)
  end

  it "records a full-price payment and marks the abonnement paid when collect_payment is set" do
    plan = create(:contract_type, price: 89)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    result = described_class.call(client: client, contract_type: plan, created_by: staff, collect_payment: true, payment_method: "bank_transfer")

    expect(result.payment).to be_paid
    expect(result.payment.amount).to eq(89)
    expect(result.contract).to be_paid
  end

  it "collects on the discounted price, not the plan price" do
    plan = create(:contract_type, price: 100)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    result = described_class.call(client: client, contract_type: plan, created_by: staff, discount: 30, collect_payment: true, payment_method: "cash")

    expect(result.payment.amount).to eq(70)
    expect(result.contract).to be_paid
  end

  it "falls back to cash when given an unsupported payment method (card is out of scope)" do
    plan = create(:contract_type, price: 50)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    result = described_class.call(client: client, contract_type: plan, created_by: staff, collect_payment: true, payment_method: "card")

    expect(result.payment.payment_method).to eq("cash")
  end

  it "leaves the abonnement unpaid and creates no payment when collect_payment is not set" do
    plan = create(:contract_type, price: 89)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)

    result = described_class.call(client: client, contract_type: plan, created_by: staff)

    expect(result.payment).to be_nil
    expect(result.contract).to be_unpaid
  end
end
