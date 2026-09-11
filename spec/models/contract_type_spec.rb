require "rails_helper"

RSpec.describe ContractType do
  describe "#duration_days" do
    it "maps each billing period to its day count" do
      expect(build(:contract_type, billing_period: :monthly).duration_days).to eq(30)
      expect(build(:contract_type, billing_period: :quarterly).duration_days).to eq(90)
      expect(build(:contract_type, billing_period: :semi_annual).duration_days).to eq(180)
      expect(build(:contract_type, billing_period: :yearly).duration_days).to eq(365)
    end
  end

  describe "validations" do
    it "rejects a color that isn't a 6-digit hex code" do
      contract_type = build(:contract_type, color: "blue")
      expect(contract_type).not_to be_valid
      expect(contract_type.errors[:color]).to be_present
    end

    it "accepts a valid hex color" do
      expect(build(:contract_type, color: "#4F46E5")).to be_valid
    end

    it "rejects a negative price" do
      contract_type = build(:contract_type, price: -1)
      expect(contract_type).not_to be_valid
      expect(contract_type.errors[:price]).to be_present
    end

    it "rejects a zero booking_limit but allows a blank one" do
      expect(build(:contract_type, booking_limit: 0)).not_to be_valid
      expect(build(:contract_type, booking_limit: nil)).to be_valid
    end

    it "rejects a zero session_count but allows a blank one" do
      expect(build(:contract_type, session_count: 0)).not_to be_valid
      expect(build(:contract_type, session_count: nil)).to be_valid
    end
  end

  describe ".active" do
    it "returns only the active contract types" do
      active = create(:contract_type, active: true)
      inactive = create(:contract_type, active: false)

      expect(ContractType.active).to include(active)
      expect(ContractType.active).not_to include(inactive)
    end
  end

  describe "#grants_access_to?" do
    it "grants access everywhere when no locations or activities are attached" do
      contract_type = create(:contract_type)
      location = create(:location, company: contract_type.company)
      activity = create(:activity, location: location)

      expect(contract_type.grants_access_to?(location: location, activity: activity)).to be true
    end

    it "restricts access to the attached locations only" do
      contract_type = create(:contract_type)
      allowed_location = create(:location, company: contract_type.company)
      other_location = create(:location, company: contract_type.company)
      create(:contract_type_location, contract_type: contract_type, location: allowed_location)
      activity = create(:activity, location: other_location)

      expect(contract_type.grants_access_to?(location: allowed_location, activity: activity)).to be true
      expect(contract_type.grants_access_to?(location: other_location, activity: activity)).to be false
    end

    it "restricts access to the attached activities only" do
      contract_type = create(:contract_type)
      location = create(:location, company: contract_type.company)
      allowed_activity = create(:activity, location: location)
      other_activity = create(:activity, location: location)
      create(:contract_type_activity, contract_type: contract_type, activity: allowed_activity)

      expect(contract_type.grants_access_to?(location: location, activity: allowed_activity)).to be true
      expect(contract_type.grants_access_to?(location: location, activity: other_activity)).to be false
    end
  end
end
