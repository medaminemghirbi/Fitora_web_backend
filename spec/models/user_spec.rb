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

  describe "#destroy" do
    it "destroys the company it owns" do
      company = create(:company)
      owner = company.owner

      owner.destroy

      expect(Company.exists?(company.id)).to be false
    end

    it "destroys its notifications" do
      user = create(:user, :owner)
      notification = create(:notification, recipient: user)

      user.destroy

      expect(Notification.exists?(notification.id)).to be false
    end
  end
end
