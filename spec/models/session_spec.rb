require "rails_helper"

RSpec.describe Session, type: :model do
  it "is invalid when ends_at is before starts_at" do
    session = build(:session, starts_at: Time.current, ends_at: 1.hour.ago)

    expect(session).not_to be_valid
    expect(session.errors[:ends_at]).to be_present
  end

  it "is invalid when the location does not match the activity's location" do
    other_location = create(:location)
    session = build(:session, location: other_location)

    expect(session).not_to be_valid
    expect(session.errors[:location]).to be_present
  end

  it "is invalid when the coach is not assigned to the session's location" do
    coach = create(:coach)
    session = build(:session, coach: coach)

    expect(session).not_to be_valid
    expect(session.errors[:coach]).to be_present
  end

  it "is valid when the coach is assigned to the session's location" do
    activity = create(:activity)
    coach = create(:coach, company: activity.location.company)
    create(:coach_location, coach: coach, location: activity.location)

    session = build(:session, activity: activity, location: activity.location, coach: coach)

    expect(session).to be_valid
  end

  describe "#full?" do
    it "is true once confirmed bookings reach capacity" do
      session = create(:session, capacity: 1)
      create(:booking, session: session, status: :confirmed)

      expect(session.reload.full?).to be true
    end
  end
end
