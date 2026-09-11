require "rails_helper"

RSpec.describe WorkContract do
  describe "status enum" do
    it "exposes a predicate method per status" do
      expect(build(:work_contract, status: :draft)).to be_draft
      expect(build(:work_contract, status: :terminated)).to be_terminated
    end
  end

  describe "payment_method enum" do
    it "exposes prefixed predicate methods" do
      work_contract = build(:work_contract, payment_method: :cash)
      expect(work_contract.pay_cash?).to be true
      expect(work_contract.pay_bank_transfer?).to be false
    end
  end

  describe "validations" do
    it "rejects an end date before the start date" do
      work_contract = build(:work_contract, starts_on: Date.new(2025, 1, 10), ends_on: Date.new(2025, 1, 1))
      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:ends_on]).to be_present
    end

    it "allows an end date on or after the start date" do
      work_contract = build(:work_contract, starts_on: Date.new(2025, 1, 1), ends_on: Date.new(2025, 1, 1))
      expect(work_contract).to be_valid
    end

    it "rejects a work_contract_type belonging to a different company" do
      work_contract = build(:work_contract, work_contract_type: create(:work_contract_type))
      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:work_contract_type]).to be_present
    end

    it "requires exactly one employee reference" do
      work_contract = build(:work_contract, staff_member: nil, coach: nil)
      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:base]).to be_present
    end

    it "rejects having both a staff member and a coach" do
      company = create(:company)
      work_contract = build(:work_contract,
        company: company,
        staff_member: create(:staff_member, company: company),
        coach: create(:coach, company: company))

      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:base]).to be_present
    end

    it "rejects a staff member belonging to a different company" do
      work_contract = build(:work_contract, staff_member: create(:staff_member))
      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:staff_member]).to be_present
    end

    it "rejects a coach belonging to a different company" do
      work_contract = build(:work_contract, :for_coach, coach: create(:coach))
      expect(work_contract).not_to be_valid
      expect(work_contract.errors[:coach]).to be_present
    end
  end

  describe "allowances normalization" do
    it "strips labels, casts amounts to floats, and drops entries without a label" do
      work_contract = build(:work_contract, allowances: [
        { "label" => "  Transport  ", "amount" => "100" },
        { "label" => "", "amount" => 20 },
        { "amount" => 30 }
      ])

      work_contract.valid?

      expect(work_contract.allowances).to eq([ { "label" => "Transport", "amount" => 100.0 } ])
    end

    it "silently drops malformed entries rather than failing validation" do
      work_contract = build(:work_contract, allowances: [ "garbage", { "amount" => 5 } ])

      expect(work_contract).to be_valid
      expect(work_contract.allowances).to eq([])
    end
  end

  describe "#employee" do
    it "returns the staff member when one is set" do
      work_contract = create(:work_contract)
      expect(work_contract.employee).to eq(work_contract.staff_member)
    end

    it "returns the coach for a coach contract" do
      work_contract = create(:work_contract, :for_coach)
      expect(work_contract.employee).to eq(work_contract.coach)
    end
  end

  describe "#employee_name" do
    it "uses the staff member's user full name" do
      work_contract = create(:work_contract)
      expect(work_contract.employee_name).to eq(work_contract.staff_member.user.full_name)
    end

    it "uses the coach's full name for a coach contract" do
      work_contract = create(:work_contract, :for_coach)
      expect(work_contract.employee_name).to eq(work_contract.coach.full_name)
    end
  end

  describe "#allowances_total and #total_monthly_gross" do
    it "sums allowance amounts on top of the gross salary" do
      work_contract = build(:work_contract, gross_monthly_salary: 1000, allowances: [
        { "label" => "Transport", "amount" => 100 },
        { "label" => "Meal", "amount" => 50 }
      ])

      expect(work_contract.allowances_total).to eq(150)
      expect(work_contract.total_monthly_gross).to eq(1150)
    end
  end

  describe ".active_first" do
    it "orders active work contracts ahead of every other status" do
      company = create(:company)
      ended = create(:work_contract, company: company, status: :ended,
        staff_member: create(:staff_member, company: company),
        work_contract_type: create(:work_contract_type, company: company))
      active = create(:work_contract, company: company, status: :active,
        staff_member: create(:staff_member, company: company),
        work_contract_type: create(:work_contract_type, company: company))

      results = WorkContract.where(company: company).active_first

      expect(results.first).to eq(active)
      expect(results.last).to eq(ended)
    end
  end
end
