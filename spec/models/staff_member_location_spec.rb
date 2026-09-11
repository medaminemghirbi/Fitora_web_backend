require "rails_helper"

RSpec.describe StaffMemberLocation do
  let(:company) { create(:company) }

  it "prevents assigning the same staff member to the same location twice" do
    staff_member = create(:staff_member, company: company)
    location = create(:location, company: company)
    create(:staff_member_location, staff_member: staff_member, location: location)

    dupe = build(:staff_member_location, staff_member: staff_member, location: location)
    expect(dupe).not_to be_valid
    expect(dupe.errors[:location_id]).to be_present
  end

  it "allows the same staff member across different locations" do
    staff_member = create(:staff_member, company: company)
    location_a = create(:location, company: company)
    location_b = create(:location, company: company)
    create(:staff_member_location, staff_member: staff_member, location: location_a)

    expect(build(:staff_member_location, staff_member: staff_member, location: location_b)).to be_valid
  end
end
