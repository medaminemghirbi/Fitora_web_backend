require "rails_helper"

RSpec.describe CoachLocation do
  let(:company) { create(:company) }

  it "prevents linking the same coach to the same location twice" do
    coach = create(:coach, company: company)
    location = create(:location, company: company)
    create(:coach_location, coach: coach, location: location)

    dupe = build(:coach_location, coach: coach, location: location)
    expect(dupe).not_to be_valid
    expect(dupe.errors[:coach_id]).to be_present
  end

  it "rejects linking a coach and a location from different companies" do
    coach = create(:coach, company: create(:company))
    location = create(:location, company: create(:company))

    coach_location = build(:coach_location, coach: coach, location: location)
    expect(coach_location).not_to be_valid
    expect(coach_location.errors[:location]).to be_present
  end

  it "allows the same coach at a different location within the same company" do
    coach = create(:coach, company: company)
    location = create(:location, company: company)

    expect(build(:coach_location, coach: coach, location: location)).to be_valid
  end
end
