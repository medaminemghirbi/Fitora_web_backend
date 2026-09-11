require "rails_helper"

RSpec.describe AbsenceType do
  it "uppercases and strips the abbreviation before validation" do
    absence_type = build(:absence_type, abbreviation: "  cp  ")
    absence_type.valid?
    expect(absence_type.abbreviation).to eq("CP")
  end

  it "rejects a duplicate abbreviation within the same company, case-insensitively" do
    company = create(:company)
    create(:absence_type, company: company, abbreviation: "CP")
    duplicate = build(:absence_type, company: company, abbreviation: "cp")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:abbreviation]).to be_present
  end

  it "allows the same abbreviation in a different company" do
    create(:absence_type, abbreviation: "CP")
    other_company_type = build(:absence_type, abbreviation: "CP")

    expect(other_company_type).to be_valid
  end

  it "prevents destroying an absence type that still has leave requests" do
    absence_type = create(:absence_type)
    create(:leave_request, company: absence_type.company, absence_type: absence_type)

    expect(absence_type.destroy).to be false
    expect(absence_type.errors[:base]).to be_present
    expect(AbsenceType.exists?(absence_type.id)).to be true
  end

  describe ".active" do
    it "only returns active absence types" do
      active = create(:absence_type, active: true)
      inactive = create(:absence_type, active: false)

      expect(AbsenceType.active).to include(active)
      expect(AbsenceType.active).not_to include(inactive)
    end
  end

  describe ".ordered" do
    it "orders by position then name" do
      company = create(:company)
      second = create(:absence_type, company: company, position: 1, name: "Z")
      first = create(:absence_type, company: company, position: 0, name: "A")

      expect(company.absence_types.ordered).to eq([ first, second ])
    end
  end

  describe ".seed_defaults_for" do
    it "creates the full default set for a company" do
      company = create(:company)

      expect { AbsenceType.seed_defaults_for(company) }.to change { company.absence_types.count }.by(AbsenceType::DEFAULTS.size)
      expect(company.absence_types.pluck(:abbreviation)).to match_array(AbsenceType::DEFAULTS.map { |d| d[:abbreviation] })
    end

    it "does not overwrite a customized default on repeated seeding" do
      company = create(:company)
      AbsenceType.seed_defaults_for(company)
      cp = company.absence_types.find_by(abbreviation: "CP")
      cp.update!(paid: false, position: 9)

      expect { AbsenceType.seed_defaults_for(company) }.not_to change { company.absence_types.count }
      expect(cp.reload.paid).to be false
      expect(cp.position).to eq(9)
    end
  end
end
