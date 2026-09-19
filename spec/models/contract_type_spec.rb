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

    it "rejects a zero booking_limit but allows a blank one" do
      expect(build(:contract_type, unlimited_bookings: false, booking_limit: 0)).not_to be_valid
      expect(build(:contract_type, unlimited_bookings: false, booking_limit: nil)).to be_valid
    end

    it "rejects a zero session_count but allows a blank one" do
      expect(build(:contract_type, unlimited_bookings: false, session_count: 0)).not_to be_valid
      expect(build(:contract_type, unlimited_bookings: false, session_count: nil)).to be_valid
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

  describe "#price_for" do
    it "returns what this activity costs under this plan" do
      contract_type = create(:contract_type)
      activity = create(:activity, company: contract_type.company)
      create(:contract_type_activity, contract_type: contract_type, activity: activity, price: 70)

      expect(contract_type.price_for(activity)).to eq(70)
    end

    it "prices each activity independently under the same plan" do
      contract_type = create(:contract_type)
      boxe = create(:activity, company: contract_type.company, name: "Boxe")
      pilates = create(:activity, company: contract_type.company, name: "Pilates")
      create(:contract_type_activity, contract_type: contract_type, activity: boxe, price: 50)
      create(:contract_type_activity, contract_type: contract_type, activity: pilates, price: 70)

      expect(contract_type.price_for(boxe)).to eq(50)
      expect(contract_type.price_for(pilates)).to eq(70)
    end

    it "is nil for an activity the plan isn't sold for" do
      contract_type = create(:contract_type)
      activity = create(:activity, company: contract_type.company)

      expect(contract_type.price_for(activity)).to be_nil
    end
  end

  describe "#grants_access_to?" do
    it "grants access at every company when none are attached, for a priced activity" do
      contract_type = create(:contract_type)
      activity = create(:activity, company: contract_type.company)
      create(:contract_type_activity, contract_type: contract_type, activity: activity, price: 60)

      expect(contract_type.grants_access_to?(activity: activity)).to be true
    end

    it "refuses an activity the plan has no price for — it simply isn't sold for it" do
      contract_type = create(:contract_type)
      unpriced = create(:activity, company: contract_type.company)

      expect(contract_type.grants_access_to?(activity: unpriced)).to be false
    end


    it "restricts access to the attached activities only" do
      contract_type = create(:contract_type)
      allowed_activity = create(:activity, company: contract_type.company)
      other_activity = create(:activity, company: contract_type.company)
      create(:contract_type_activity, contract_type: contract_type, activity: allowed_activity)

      expect(contract_type.grants_access_to?(activity: allowed_activity)).to be true
      expect(contract_type.grants_access_to?(activity: other_activity)).to be false
    end
  end
end
