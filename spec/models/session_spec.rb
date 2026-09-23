require "rails_helper"

RSpec.describe Session, type: :model do
  it "is invalid when ends_at is before starts_at" do
    session = build(:session, starts_at: Time.current, ends_at: 1.hour.ago)

    expect(session).not_to be_valid
    expect(session.errors[:ends_at]).to be_present
  end

  it "refuses an activity that belongs to another gym" do
    session = build(:session, company: create(:company))

    expect(session).not_to be_valid
    expect(session.errors[:activity]).to be_present
  end

  it "refuses a coach who belongs to another gym" do
    session = build(:session, coach: create(:coach))

    expect(session).not_to be_valid
    expect(session.errors[:coach]).to be_present
  end

  it "is valid when the coach is assigned to the session's company" do
    activity = create(:activity)
    coach = create(:coach, company: activity.company)

    session = build(:session, activity: activity, company: activity.company, coach: coach)

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
