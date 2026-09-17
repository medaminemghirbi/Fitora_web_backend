require "rails_helper"

RSpec.describe Contract do
  let(:company) { create(:company) }

  describe "validations" do
    it "requires an activity" do
      contract = build(:contract, activity: nil)

      expect(contract).not_to be_valid
      expect(contract.errors[:activity]).to be_present
    end

    it "rejects a second contract for the same client, contract type, and activity" do
      client = create(:client, company: company)
      contract_type = create(:contract_type, company: company)
      activity = create(:activity, company: company)
      create(:contract, client: client, contract_type: contract_type, company: company, activity: activity)

      duplicate = build(:contract, client: client, contract_type: contract_type, company: company, activity: activity)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:client_id]).to be_present
    end

    it "allows the same client and contract type again for a different activity" do
      client = create(:client, company: company)
      contract_type = create(:contract_type, company: company)
      create(:contract, client: client, contract_type: contract_type, company: company, activity: create(:activity, company: company))

      second = build(:contract, client: client, contract_type: contract_type, company: company, activity: create(:activity, company: company))

      expect(second).to be_valid
    end
  end

  describe "delegation to the current period" do
    it "reads status/dates/pricing from the latest period rather than an earlier one" do
      contract = create(:contract, status: :expired, starts_at: 60.days.ago, expires_at: 30.days.ago)
      newer_period = create(:contract_period,
        contract: contract, status: :active, starts_at: 1.day.ago, expires_at: 29.days.from_now)

      expect(contract.current_period).to eq(newer_period)
      expect(contract.status).to eq("active")
      expect(contract).to be_active
    end

    it "returns nil rather than raising when the contract has no periods" do
      contract = build(:contract)
      contract.save!(validate: false)

      expect(contract.current_period).to be_nil
      expect(contract.status).to be_nil
      expect(contract.remaining_bookings).to be_nil
    end
  end

  describe "#usable_for?" do
    it "is false when the current period isn't active" do
      contract = create(:contract, status: :pending)
      company = contract.activity.company

      expect(contract.usable_for?(activity: contract.activity)).to be false
    end

    it "is false once the period has expired, even if its status is still active" do
      contract = create(:contract, status: :active, expires_at: 1.day.ago)
      company = contract.activity.company

      expect(contract.usable_for?(activity: contract.activity)).to be false
    end

    it "is false when the plan is limited and no bookings remain" do
      contract_type = create(:contract_type, unlimited_bookings: false, booking_limit: 10)
      contract = create(:contract, contract_type: contract_type, remaining_bookings: 0)
      company = contract.activity.company

      expect(contract.usable_for?(activity: contract.activity)).to be false
    end

    it "is true for an active, unexpired contract with bookings left, delegating to the plan's access rules" do
      contract_type = create(:contract_type, unlimited_bookings: false, booking_limit: 10)
      contract = create(:contract, contract_type: contract_type, remaining_bookings: 3)
      company = contract.activity.company

      expect(contract.usable_for?(activity: contract.activity)).to be true
    end

    it "is false for any activity other than the one the contract itself was issued for, even one the plan would otherwise allow" do
      contract = create(:contract)
      other_activity = create(:activity, company: contract.company)

      expect(contract.usable_for?(activity: other_activity)).to be false
    end
  end

  describe "#consume_booking!" do
    it "decrements the current period's remaining_bookings for a limited plan" do
      contract_type = create(:contract_type, unlimited_bookings: false, booking_limit: 10)
      contract = create(:contract, contract_type: contract_type, remaining_bookings: 5)

      contract.consume_booking!

      expect(contract.current_period.reload.remaining_bookings).to eq(4)
    end

    it "does nothing for an unlimited plan" do
      contract = create(:contract, remaining_bookings: nil)

      expect { contract.consume_booking! }.not_to raise_error
      expect(contract.current_period.reload.remaining_bookings).to be_nil
    end

    it "does nothing when the period tracks no session count" do
      contract_type = create(:contract_type, unlimited_bookings: false, booking_limit: 10)
      contract = create(:contract, contract_type: contract_type, remaining_bookings: nil)

      expect { contract.consume_booking! }.not_to raise_error
      expect(contract.current_period.reload.remaining_bookings).to be_nil
    end
  end

  describe "#restore_booking!" do
    it "increments the current period's remaining_bookings for a limited plan" do
      contract_type = create(:contract_type, unlimited_bookings: false, booking_limit: 10)
      contract = create(:contract, contract_type: contract_type, remaining_bookings: 5)

      contract.restore_booking!

      expect(contract.current_period.reload.remaining_bookings).to eq(6)
    end

    it "does nothing for an unlimited plan" do
      contract = create(:contract, remaining_bookings: nil)

      expect { contract.restore_booking! }.not_to raise_error
      expect(contract.current_period.reload.remaining_bookings).to be_nil
    end
  end
end
