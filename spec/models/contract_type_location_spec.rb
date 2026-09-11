require "rails_helper"

RSpec.describe ContractTypeLocation do
  it "rejects attaching the same location twice to the same contract type" do
    contract_type = create(:contract_type)
    location = create(:location)
    create(:contract_type_location, contract_type: contract_type, location: location)

    duplicate = build(:contract_type_location, contract_type: contract_type, location: location)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:location_id]).to be_present
  end

  it "allows the same location to be attached to a different contract type" do
    location = create(:location)
    create(:contract_type_location, contract_type: create(:contract_type), location: location)

    other = build(:contract_type_location, contract_type: create(:contract_type), location: location)

    expect(other).to be_valid
  end
end
