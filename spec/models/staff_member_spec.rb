require "rails_helper"

RSpec.describe StaffMember, type: :model do
  describe "capabilities" do
    it "grants a coach only checkin (attendance-marking) — no client/schedule management" do
      staff = build(:staff_member, role: :coach)

      expect(staff.can?(:checkin)).to be true
      expect(staff.can?(:sessions)).to be false
      expect(staff.can?(:locations)).to be false
      expect(staff.can?(:clients)).to be false
      expect(staff.can?(:payments)).to be false
    end

    it "grants a receptionist the daily-ops set — not the config capabilities" do
      staff = build(:staff_member, role: :receptionist)

      expect(staff.can?(:sessions)).to be true
      expect(staff.can?(:bookings)).to be true
      expect(staff.can?(:clients)).to be true
      expect(staff.can?(:contracts)).to be true
      expect(staff.can?(:payments)).to be true
      expect(staff.can?(:checkin)).to be true
      expect(staff.can?(:reports)).to be true

      expect(staff.can?(:locations)).to be false
      expect(staff.can?(:activities)).to be false
      expect(staff.can?(:contract_types)).to be false
      expect(staff.can?(:coaches)).to be false
    end
  end

  describe "role assignment" do
    it "keeps a custom assigned_role instead of syncing it from the enum kind" do
      company = create(:company)
      custom = create(:role, company: company, permissions: %w[payments])
      staff = create(:staff_member, company: company, role: :receptionist, assigned_role: custom)

      expect(staff.reload.assigned_role).to eq(custom)
      expect(staff.role_key).to eq(custom.key)
      expect(staff.can?(:payments)).to be true
      expect(staff.can?(:sessions)).to be false
    end
  end

  describe "validations" do
    it "rejects a coach_id on a non-coach role" do
      company = create(:company)
      coach = create(:coach, company: company)
      staff = build(:staff_member, role: :receptionist, company: company, coach: coach)

      expect(staff).not_to be_valid
    end

    it "rejects a coach from a different company" do
      company = create(:company)
      other_org_coach = create(:coach)
      staff = build(:staff_member, role: :coach, company: company, coach: other_org_coach)

      expect(staff).not_to be_valid
    end

    it "only allows one staff record per user" do
      user = create(:user, :staff)
      create(:staff_member, user: user)
      duplicate = build(:staff_member, user: user)

      expect(duplicate).not_to be_valid
    end
  end
end
