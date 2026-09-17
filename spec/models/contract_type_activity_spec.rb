require "rails_helper"

RSpec.describe ContractTypeActivity do
  it "rejects attaching the same activity twice to the same contract type" do
    contract_type = create(:contract_type)
    activity = create(:activity)
    create(:contract_type_activity, contract_type: contract_type, activity: activity)

    duplicate = build(:contract_type_activity, contract_type: contract_type, activity: activity)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:activity_id]).to be_present
  end

  it "rejects a negative price" do
    row = build(:contract_type_activity, price: -1)

    expect(row).not_to be_valid
    expect(row.errors[:price]).to be_present
  end

  it "allows the same activity to be attached to a different contract type" do
    activity = create(:activity)
    create(:contract_type_activity, contract_type: create(:contract_type), activity: activity)

    other = build(:contract_type_activity, contract_type: create(:contract_type), activity: activity)

    expect(other).to be_valid
  end
end
