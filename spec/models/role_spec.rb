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

    it "matches the legacy StaffMember::CAPABILITIES map for each staff kind" do
      described_class.seed_defaults_for(company)
      StaffMember::CAPABILITIES.each do |enum_key, caps|
        role = company.roles.find_by(key: enum_key.to_s)
        expect(role.permissions).to match_array(caps.map(&:to_s))
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
end
