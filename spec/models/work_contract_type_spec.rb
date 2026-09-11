require "rails_helper"

RSpec.describe WorkContractType do
  describe "validations" do
    it "rejects a duplicate abbreviation within the same company, case-insensitively" do
      company = create(:company)
      create(:work_contract_type, company: company, abbreviation: "CDI")

      duplicate = build(:work_contract_type, company: company, abbreviation: "cdi")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:abbreviation]).to be_present
    end

    it "allows the same abbreviation in a different company" do
      create(:work_contract_type, abbreviation: "CDI")

      other = build(:work_contract_type, abbreviation: "CDI")

      expect(other).to be_valid
    end
  end

  it "normalizes the abbreviation to a stripped, upcased value" do
    work_contract_type = create(:work_contract_type, abbreviation: "  cdd  ")
    expect(work_contract_type.abbreviation).to eq("CDD")
  end

  it "rejects a blank abbreviation once normalized" do
    work_contract_type = build(:work_contract_type, abbreviation: "   ")
    expect(work_contract_type).not_to be_valid
    expect(work_contract_type.errors[:abbreviation]).to be_present
  end

  describe ".active" do
    it "returns only the active work contract types" do
      active = create(:work_contract_type, active: true)
      inactive = create(:work_contract_type, active: false)

      expect(WorkContractType.active).to include(active)
      expect(WorkContractType.active).not_to include(inactive)
    end
  end

  describe ".ordered" do
    it "orders by position, then name" do
      company = create(:company)
      second = create(:work_contract_type, company: company, position: 1, name: "B")
      first = create(:work_contract_type, company: company, position: 0, name: "A")

      expect(WorkContractType.where(company: company).ordered).to eq([ first, second ])
    end
  end

  describe ".seed_defaults_for" do
    it "creates the standard Tunisian contract set for a company" do
      company = create(:company)

      WorkContractType.seed_defaults_for(company)

      expect(company.work_contract_types.pluck(:abbreviation)).to match_array(
        WorkContractType::DEFAULTS.map { |d| d[:abbreviation] }
      )
    end

    it "is idempotent and doesn't duplicate defaults on repeated calls" do
      company = create(:company)

      WorkContractType.seed_defaults_for(company)
      WorkContractType.seed_defaults_for(company)

      expect(company.work_contract_types.count).to eq(WorkContractType::DEFAULTS.size)
    end

    it "does not override a name the owner has already customized" do
      company = create(:company)
      WorkContractType.seed_defaults_for(company)
      cdi = company.work_contract_types.find_by(abbreviation: "CDI")
      cdi.update!(name: "Custom CDI Name")

      WorkContractType.seed_defaults_for(company)

      expect(cdi.reload.name).to eq("Custom CDI Name")
    end
  end
end
