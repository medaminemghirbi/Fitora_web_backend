require "rails_helper"

RSpec.describe Location do
  let(:company) { create(:company) }

  it "requires a name and a timezone" do
    location = build(:location, company: company, name: nil, timezone: nil)
    expect(location).not_to be_valid
    expect(location.errors[:name]).to be_present
    expect(location.errors[:timezone]).to be_present
  end

  describe ".active" do
    it "only returns active locations" do
      active = create(:location, company: company, active: true)
      inactive = create(:location, company: company, active: false)

      expect(Location.active).to include(active)
      expect(Location.active).not_to include(inactive)
    end
  end

  describe "#destroy" do
    it "destroys its activities and sessions" do
      location = create(:location, company: company)
      activity = create(:activity, location: location)
      session = create(:session, activity: activity, location: location)

      location.destroy

      expect(Activity.exists?(activity.id)).to be false
      expect(Session.exists?(session.id)).to be false
    end

    it "destroys coach_locations and staff_member_locations but not the coaches or staff members themselves" do
      location = create(:location, company: company)
      coach = create(:coach, company: company)
      coach_location = create(:coach_location, coach: coach, location: location)
      staff_member = create(:staff_member, company: company)
      staff_member_location = create(:staff_member_location, staff_member: staff_member, location: location)

      location.destroy

      expect(CoachLocation.exists?(coach_location.id)).to be false
      expect(StaffMemberLocation.exists?(staff_member_location.id)).to be false
      expect(Coach.exists?(coach.id)).to be true
      expect(StaffMember.exists?(staff_member.id)).to be true
    end
  end
end
