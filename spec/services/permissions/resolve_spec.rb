require "rails_helper"

RSpec.describe Permissions::Resolve do
  it "grants a platform admin no role and no permissions" do
    admin = create(:user, :admin)

    result = described_class.call(user: admin)

    expect(result.role).to be_nil
    expect(result.permissions).to eq([])
  end

  it "grants the owner every permission the product exposes, under the company's owner role" do
    company = create(:company)

    result = described_class.call(user: company.owner)

    expect(result.role).to eq(key: "owner", name: "Propriétaire")
    expect(result.permissions).to match_array(ModuleCatalog::ALL_PERMISSIONS)
  end

  it "resolves permissions from a custom role assigned to a staff member" do
    company = create(:company)
    custom_role = create(:role, company: company, key: "accountant", name: "Comptable",
                                 permissions: %w[clients payments], builtin: false)
    user = create(:user, :staff)
    create(:staff_member, company: company, user: user, role: :receptionist, assigned_role: custom_role)

    result = described_class.call(user: user)

    expect(result.role).to eq(key: "accountant", name: "Comptable")
    expect(result.permissions).to match_array(%w[clients payments])
  end

  it "falls back to the built-in role matching the staff member's enum role when none is explicitly assigned" do
    company = create(:company)
    user = create(:user, :staff)
    create(:staff_member, company: company, user: user, role: :coach)

    result = described_class.call(user: user)

    expect(result.role).to eq(key: "coach", name: "Coach")
    expect(result.permissions).to match_array(%w[checkin])
  end

  it "returns no role and no permissions for a staff user with no company or staff record" do
    user = create(:user, :staff)

    result = described_class.call(user: user)

    expect(result.role).to be_nil
    expect(result.permissions).to eq([])
  end
end
