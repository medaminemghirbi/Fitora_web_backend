require "rails_helper"

RSpec.describe User do
  it "downcases and strips the email before validation" do
    user = create(:user, :owner, email: "  Test@Example.COM ")
    expect(user.email).to eq("test@example.com")
  end

  it "rejects a locale outside the supported set" do
    user = build(:user, :owner, locale: "de")
    expect(user).not_to be_valid
    expect(user.errors[:locale]).to be_present
  end

  it "requires a minimum password length on create" do
    user = build(:user, :owner, password: "short")
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "does not require re-entering a password on an update that leaves it alone" do
    user = create(:user, :owner)
    reloaded = User.find(user.id)
    reloaded.first_name = "Changed"

    expect(reloaded).to be_valid
  end

  it "builds the full name from first and last name" do
    user = build(:user, first_name: "Jane", last_name: "Doe")
    expect(user.full_name).to eq("Jane Doe")
  end

  describe "role" do
    it "exposes owner/staff/admin as predicate methods via the enum" do
      expect(create(:user, :owner)).to be_owner
      expect(create(:user, :staff)).to be_staff
      expect(create(:user, :admin)).to be_admin
    end
  end

  describe ".active" do
    it "only returns active users" do
      active = create(:user, :owner, active: true)
      inactive = create(:user, :owner, active: false)

      expect(User.active).to include(active)
      expect(User.active).not_to include(inactive)
    end
  end

  it "rejects a company_limit outside the two capped tiers (1 or 3; nil is the unlimited tier)" do
    expect(build(:user, :owner, company_limit: 2)).not_to be_valid
    expect(build(:user, :owner, company_limit: 1)).to be_valid
    expect(build(:user, :owner, company_limit: 3)).to be_valid
    expect(build(:user, :owner, company_limit: nil)).to be_valid
  end

  describe "#company_limit_reached?" do
    it "is true once companies.count reaches a capped limit" do
      owner = create(:user, :owner, company_limit: 1)
      create(:company, owner: owner)

      expect(owner.company_limit_reached?).to be true
    end

    it "is never true on the unlimited (nil) tier" do
      owner = create(:user, :owner, company_limit: nil)
      create_list(:company, 5, owner: owner)

      expect(owner.company_limit_reached?).to be false
    end
  end

  describe "#switch_active_company!" do
    it "moves active_company to another of the owner's own companies" do
      owner = create(:user, :owner, company_limit: nil)
      first = create(:company, owner: owner)
      second = create(:company, owner: owner)

      expect(owner.switch_active_company!(second)).to be true
      expect(owner.reload.active_company).to eq(second)
      expect(first).to be_present # sanity: still exists, just no longer active
    end

    it "refuses to switch onto a company this owner doesn't own" do
      owner = create(:user, :owner)
      other_company = create(:company)

      expect(owner.switch_active_company!(other_company)).to be false
      expect(owner.reload.active_company).not_to eq(other_company)
    end
  end

  describe "#destroy" do
    it "destroys the company it owns" do
      company = create(:company)
      owner = company.owner

      owner.destroy

      expect(Company.exists?(company.id)).to be false
    end

    it "destroys every company it owns, even when several exist" do
      owner = create(:user, :owner, company_limit: nil)
      companies = create_list(:company, 3, owner: owner)

      owner.destroy

      expect(Company.where(id: companies.map(&:id))).to be_none
    end

    it "destroys its notifications" do
      user = create(:user, :owner)
      notification = create(:notification, recipient: user)

      user.destroy

      expect(Notification.exists?(notification.id)).to be false
    end
  end
end
