require "rails_helper"

RSpec.describe Contracts::Renew do
  it "adds a new period to the same contract, starting exactly when the current one expires" do
    plan = create(:contract_type)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)
    original = create(:contract, client: client, contract_type: plan, company: plan.company,
                                    starts_at: 30.days.ago, expires_at: 5.days.from_now)
    original_period = original.current_period

    result = described_class.call(contract: original, created_by: staff)

    expect(result.success?).to be true
    expect(result.contract.id).to eq(original.id)
    expect(result.contract.contract_periods.count).to eq(2)
    expect(result.contract.starts_at.to_date).to eq(original_period.expires_at.to_date)
    expect(result.contract.expires_at.to_date).to eq(original_period.expires_at.to_date + 30.days)
    expect(original_period.reload.status).to eq("active")
  end

  it "starts the new period today when the current one has already expired" do
    plan = create(:contract_type)
    client = create(:client, company: plan.company)
    staff = create(:user, :owner)
    original = create(:contract, client: client, contract_type: plan, company: plan.company,
                                    starts_at: 40.days.ago, expires_at: 10.days.ago, status: :expired)

    result = described_class.call(contract: original, created_by: staff)

    expect(result.contract.starts_at.to_date).to eq(Date.current)
  end
end
