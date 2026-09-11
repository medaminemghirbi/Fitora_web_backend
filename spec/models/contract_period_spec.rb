require "rails_helper"

RSpec.describe ContractPeriod do
  describe "validations" do
    it "requires starts_at when the status is active" do
      period = build(:contract_period, status: :active, starts_at: nil)
      expect(period).not_to be_valid
      expect(period.errors[:starts_at]).to be_present
    end

    it "allows a blank starts_at when the status isn't active" do
      period = build(:contract_period, status: :pending, starts_at: nil)
      expect(period).to be_valid
    end

    it "rejects a negative discount" do
      period = build(:contract_period, discount: -1)
      expect(period).not_to be_valid
      expect(period.errors[:discount]).to be_present
    end
  end

  describe "#compute_final_price" do
    it "sets final_price to the plan price minus the discount" do
      contract_type = create(:contract_type, price: 100)
      contract = create(:contract, contract_type: contract_type)
      period = build(:contract_period, contract: contract, discount: 15)

      period.valid?

      expect(period.final_price).to eq(85)
    end

    it "floors final_price at zero when the discount exceeds the plan price" do
      contract_type = create(:contract_type, price: 50)
      contract = create(:contract, contract_type: contract_type)
      period = build(:contract_period, contract: contract, discount: 999)

      period.valid?

      expect(period.final_price).to eq(0)
    end
  end

  describe ".currently_active" do
    it "includes only active periods with no expiry or a future expiry" do
      not_expired = create(:contract_period, status: :active, expires_at: 5.days.from_now)
      no_expiry = create(:contract_period, status: :active, expires_at: nil)
      expired = create(:contract_period, status: :active, expires_at: 1.day.ago)
      pending = create(:contract_period, status: :pending, expires_at: 5.days.from_now)

      results = ContractPeriod.currently_active

      expect(results).to include(not_expired, no_expiry)
      expect(results).not_to include(expired, pending)
    end
  end

  describe ".expiring_soon" do
    it "returns currently active periods whose expiry falls within the given window" do
      soon = create(:contract_period, status: :active, expires_at: 5.days.from_now)
      later = create(:contract_period, status: :active, expires_at: 40.days.from_now)

      results = ContractPeriod.expiring_soon(within: 10.days)

      expect(results).to include(soon)
      expect(results).not_to include(later)
    end
  end

  describe "#expiring_soon?" do
    it "is false when the status isn't active" do
      period = build(:contract_period, status: :pending, expires_at: 5.days.from_now)
      expect(period.expiring_soon?).to be false
    end

    it "is false when the expiry is farther out than the window" do
      period = build(:contract_period, status: :active, expires_at: 20.days.from_now)
      expect(period.expiring_soon?(within: 14.days)).to be false
    end

    it "is true when active and the expiry falls within the window" do
      period = build(:contract_period, status: :active, expires_at: 5.days.from_now)
      expect(period.expiring_soon?(within: 14.days)).to be true
    end
  end

  describe "expiry notifications" do
    it "notifies when a new period is created already expiring soon" do
      expect(Notifications::ContractExpiryChangedJob).to receive(:perform_later)

      create(:contract_period, status: :active, expires_at: 5.days.from_now)
    end

    it "notifies when an existing period's expiry is updated into the warning window" do
      period = create(:contract_period, status: :active, expires_at: 60.days.from_now)

      expect(Notifications::ContractExpiryChangedJob).to receive(:perform_later).with(period.id)

      period.update!(expires_at: 5.days.from_now)
    end

    it "does not notify again when an unrelated attribute changes" do
      period = create(:contract_period, status: :active, expires_at: 5.days.from_now)

      expect(Notifications::ContractExpiryChangedJob).not_to receive(:perform_later)

      period.update!(discount: 10)
    end
  end
end
