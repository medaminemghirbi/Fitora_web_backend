require "rails_helper"

RSpec.describe Contract do
  let(:company) { create(:company) }

  describe "validations" do
    it "allows a contract with no activity — that is the all-access kind" do
      contract = build(:contract, activity: nil)

      expect(contract).to be_valid
      expect(contract).to be_all_access
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

  describe "#covers_activity?" do
    let(:pilates) { create(:activity, company: company) }
    let(:boxing) { create(:activity, company: company) }
    let(:yoga) { create(:activity, company: company) }
    # The plan is priced for pilates and boxing, and deliberately not yoga —
    # `activity:` is the row the factory seeds, so the plan covers exactly
    # these two and nothing else.
    let(:plan) { create(:contract_type, company: company, activity: pilates) }

    before { create(:contract_type_activity, contract_type: plan, activity: boxing) }

    it "covers only its own activity when it names one" do
      contract = create(:contract, contract_type: plan, activity: pilates)

      expect(contract.covers_activity?(pilates)).to be(true)
      expect(contract.covers_activity?(boxing)).to be(false)
    end

    it "covers every activity on the plan when it names none" do
      contract = create(:contract, contract_type: plan, activity: nil)

      expect(contract.covers_activity?(pilates)).to be(true)
      expect(contract.covers_activity?(boxing)).to be(true)
    end

    it "does not cover an activity the plan itself does not, even all-access" do
      contract = create(:contract, contract_type: plan, activity: nil)

      expect(contract.covers_activity?(yoga)).to be(false)
    end

    it "stops covering an activity once the plan drops it" do
      contract = create(:contract, contract_type: plan, activity: nil)
      plan.contract_type_activities.find_by(activity_id: boxing.id).destroy!

      expect(contract.reload.covers_activity?(boxing)).to be(false)
      expect(contract.covers_activity?(pilates)).to be(true)
    end

    it "is false for a nil activity rather than raising" do
      contract = create(:contract, contract_type: plan, activity: nil)

      expect(contract.covers_activity?(nil)).to be(false)
    end

    it "lists what it covers" do
      named = create(:contract, contract_type: plan, activity: pilates)
      all_access = create(:contract, contract_type: plan, activity: nil)

      expect(named.covered_activities).to contain_exactly(pilates)
      expect(all_access.covered_activities).to contain_exactly(pilates, boxing)
    end
  end
end
