require "rails_helper"

RSpec.describe Coaches::SetLogin do
  it "provisions a new staff login for a coach without one" do
    coach = create(:coach)

    result = described_class.call(coach: coach, email: "coach@example.com", password: "password123")

    expect(result.success?).to be true
    expect(result.error).to be_nil

    staff_member = result.staff_member
    expect(staff_member).to be_persisted
    expect(staff_member.coach).to eq(coach)
    expect(staff_member.role).to eq("coach")
    expect(staff_member.company).to eq(coach.company)
    expect(staff_member.user.email).to eq("coach@example.com")
    expect(staff_member.user.role).to eq("staff")
    expect(staff_member.staff_member_locations.pluck(:location_id)).to eq([ coach.company.location.id ])
    expect(coach.reload.staff_member).to eq(staff_member)
  end

  it "resets the linked user's credentials when the coach already has a login" do
    coach = create(:coach)
    described_class.call(coach: coach, email: "old@example.com", password: "password123")
    existing_staff_member = coach.reload.staff_member

    result = described_class.call(coach: coach, email: "new@example.com", password: "newpassword123")

    expect(result.success?).to be true
    expect(result.staff_member.id).to eq(existing_staff_member.id)
    expect(result.staff_member.user.email).to eq("new@example.com")
    expect(result.staff_member.user.authenticate("newpassword123")).to be_truthy
    expect(StaffMember.where(coach: coach).count).to eq(1)
  end

  it "fails with a friendly error when the email is already taken" do
    create(:user, email: "taken@example.com")
    coach = create(:coach)

    result = described_class.call(coach: coach, email: "taken@example.com", password: "password123")

    expect(result.success?).to be false
    expect(result.staff_member).to be_nil
    expect(result.error).to be_present
    expect(coach.reload.staff_member).to be_nil
  end
end
