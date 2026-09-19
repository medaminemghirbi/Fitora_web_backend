require "rails_helper"

RSpec.describe Role do
  describe "normalisation" do
    it "drops unknown permission keys and de-dupes, keeping catalogue order" do
      role = build(:role, permissions: %w[payments bogus clients payments])
      role.valid?
      expect(role.permissions).to eq(%w[clients payments])
    end

    it "slugifies the key" do
      role = build(:role, key: "Front Desk Lead")
      role.valid?
      expect(role.key).to eq("front_desk_lead")
    end
  end

  describe ".seed_defaults_for" do
    let(:company) { create(:company) }

    it "creates exactly the built-in roles, idempotently" do
      # the company factory already seeds them once; calling again is a no-op
      expect { 2.times { described_class.seed_defaults_for(company) } }
        .not_to change { company.roles.reload.count }
      expect(company.roles.pluck(:key)).to match_array(Role::SYSTEM_KEYS)
      expect(company.roles.where(builtin: true).count).to eq(Role::SYSTEM_KEYS.size)
    end

    it "gives each built-in role the permissions it is defined with" do
      described_class.seed_defaults_for(company)
      described_class::DEFAULTS.each do |key, attrs|
        role = company.roles.find_by(key: key)
        expect(role.permissions).to match_array(attrs[:permissions])
      end
    end
  end

  describe "#deletable?" do
    let(:company) { create(:company) }

    it "is false for built-in roles" do
      expect(company.roles.find_by(key: "receptionist")).not_to be_deletable
    end

    it "is true for an unused custom role, false once staff are assigned" do
      role = create(:role, company: company)
      expect(role).to be_deletable

      create(:staff_member, company: company, role: :receptionist, assigned_role: role)
      expect(role.reload).not_to be_deletable
    end
  end

  describe "the Modérateur role" do
    it "is the only role below the owner that can add coaches" do
      company = create(:company)
      by_key = company.roles.index_by(&:key)

      expect(by_key["moderator"].permissions).to include("coaches")
      expect(by_key["receptionist"].permissions).not_to include("coaches")
      expect(by_key["coach"].permissions).not_to include("coaches")
    end

    it "still leaves the catalogues and the plans to the owner" do
      company = create(:company)
      moderator = company.roles.find_by(key: "moderator")

      expect(moderator.permissions).not_to include("activities")
      expect(moderator.permissions).not_to include("contract_types")
    end

    it "reaches a company created before the role existed, without touching a re-permissioned one" do
      company = create(:company)
      company.roles.find_by(key: "moderator").destroy
      company.roles.find_by(key: "receptionist").update!(permissions: %w[clients])

      Role.seed_defaults_for(company)

      expect(company.roles.reload.find_by(key: "moderator")).to be_present
      expect(company.roles.find_by(key: "receptionist").permissions).to eq(%w[clients])
    end
  end
end
