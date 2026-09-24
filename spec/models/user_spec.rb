require "rails_helper"

RSpec.describe User do
  it "downcases and strips the email before validation" do
    user = create(:user, :admin, email: "  Test@Example.COM ")
    expect(user.email).to eq("test@example.com")
  end

  it "rejects a locale outside the supported set" do
    user = build(:user, :admin, locale: "de")
    expect(user).not_to be_valid
    expect(user.errors[:locale]).to be_present
  end

  it "requires a minimum password length on create" do
    user = build(:user, :admin, password: "short")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "does not require re-entering a password on an update that leaves it alone" do
    user = create(:user, :admin)
    reloaded = User.find(user.id)
    reloaded.first_name = "Changed"

    expect(reloaded).to be_valid
  end

  it "builds the full name from first and last name" do
    user = build(:user, first_name: "Jane", last_name: "Doe")
    expect(user.full_name).to eq("Jane Doe")
  end

  describe "role" do
    it "exposes admin/staff/superadmin as predicate methods via the enum" do
      expect(create(:user, :admin)).to be_admin
      expect(create(:user, :staff)).to be_staff
      expect(create(:user, :superadmin)).to be_superadmin
    end
  end

  describe ".active" do
    it "only returns active users" do
      active = create(:user, :admin, active: true)
      inactive = create(:user, :admin, active: false)

      expect(User.active).to include(active)
      expect(User.active).not_to include(inactive)
    end
  end

  it "rejects a company_limit outside the two capped tiers (1 or 3; nil is the unlimited tier)" do
    expect(build(:user, :admin, company_limit: 2)).not_to be_valid
    expect(build(:user, :admin, company_limit: 1)).to be_valid
    expect(build(:user, :admin, company_limit: 3)).to be_valid
    expect(build(:user, :admin, company_limit: nil)).to be_valid
  end

  describe "#company_limit_reached?" do
    it "is true once companies.count reaches a capped limit" do
      admin = create(:user, :admin, company_limit: 1)
      create(:company, admin: admin)

      expect(admin.company_limit_reached?).to be true
    end

    it "is never true on the unlimited (nil) tier" do
      admin = create(:user, :admin, company_limit: nil)
      create_list(:company, 5, admin: admin)

      expect(admin.company_limit_reached?).to be false
    end
  end

  describe "#switch_active_company!" do
    it "moves active_company to another of the admin's own companies" do
      admin = create(:user, :admin, company_limit: nil)
      first = create(:company, admin: admin)
      second = create(:company, admin: admin)

      expect(admin.switch_active_company!(second)).to be true
      expect(admin.reload.active_company).to eq(second)
      expect(first).to be_present # sanity: still exists, just no longer active
    end

    it "refuses to switch onto a company this admin doesn't own" do
      admin = create(:user, :admin)
      other_company = create(:company)

      expect(admin.switch_active_company!(other_company)).to be false
      expect(admin.reload.active_company).not_to eq(other_company)
    end
  end

  describe "#destroy" do
    it "destroys the company it owns" do
      company = create(:company)
      admin = company.admin

      admin.destroy

      expect(Company.exists?(company.id)).to be false
    end

    it "destroys every company it owns, even when several exist" do
      admin = create(:user, :admin, company_limit: nil)
      companies = create_list(:company, 3, admin: admin)

      admin.destroy

      expect(Company.where(id: companies.map(&:id))).to be_none
    end

    it "destroys its notifications" do
      user = create(:user, :admin)
      notification = create(:notification, recipient: user)

      user.destroy

      expect(Notification.exists?(notification.id)).to be false
    end
  end
end
