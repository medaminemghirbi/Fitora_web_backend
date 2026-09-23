require "rails_helper"

RSpec.describe ActivitySpace do
  let(:company) { create(:company) }

  it "links an activity to a room in the same gym" do
    activity = create(:activity, company: company)
    space = create(:space, company: company)

    expect(build(:activity_space, activity: activity, space: space)).to be_valid
  end

  it "refuses to put an activity in another gym's room" do
    link = build(:activity_space,
      activity: create(:activity, company: company),
      space: create(:space, company: create(:company)))

    expect(link).not_to be_valid
    expect(link.errors[:space]).to be_present
  end

  it "does not link the same pair twice" do
    activity = create(:activity, company: company)
    space = create(:space, company: company)
    create(:activity_space, activity: activity, space: space)

    expect(build(:activity_space, activity: activity, space: space)).not_to be_valid
  end
end
