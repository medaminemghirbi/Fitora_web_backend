require "rails_helper"

RSpec.describe Sessions::Create do
  it "creates a session with valid attributes" do
    activity = create(:activity)

    result = described_class.call(attributes: {
      activity_id: activity.id,
      location_id: activity.location_id,
      starts_at: 1.day.from_now.change(hour: 10),
      ends_at: 1.day.from_now.change(hour: 11),
      capacity: 10,
      price: 20
    })

    expect(result.success?).to be true
    expect(result.session).to be_persisted
  end

  it "rejects a coach's overlapping session with a friendly error, even across locations" do
    company = create(:company)
    location_a = create(:location, company: company)
    location_b = create(:location, company: company)
    activity_a = create(:activity, location: location_a)
    activity_b = create(:activity, location: location_b)
    coach = create(:coach, company: company)
    create(:coach_location, coach: coach, location: location_a)
    create(:coach_location, coach: coach, location: location_b)

    starts_at = 2.days.from_now.change(hour: 18)

    first = described_class.call(attributes: {
      activity_id: activity_a.id, location_id: location_a.id, coach_id: coach.id,
      starts_at: starts_at, ends_at: starts_at + 1.hour, capacity: 10, price: 20
    })
    expect(first.success?).to be true

    overlapping_start = starts_at + 30.minutes
    second = described_class.call(attributes: {
      activity_id: activity_b.id, location_id: location_b.id, coach_id: coach.id,
      starts_at: overlapping_start, ends_at: overlapping_start + 1.hour, capacity: 10, price: 20
    })

    expect(second.success?).to be false
    expect(second.error).to eq("Coach already has a session at that time.")
  end

  it "allows back-to-back non-overlapping sessions for the same coach" do
    company = create(:company)
    location = create(:location, company: company)
    activity = create(:activity, location: location)
    coach = create(:coach, company: company)
    create(:coach_location, coach: coach, location: location)

    starts_at = 2.days.from_now.change(hour: 18)

    first = described_class.call(attributes: {
      activity_id: activity.id, location_id: location.id, coach_id: coach.id,
      starts_at: starts_at, ends_at: starts_at + 1.hour, capacity: 10, price: 20
    })
    expect(first.success?).to be true

    second = described_class.call(attributes: {
      activity_id: activity.id, location_id: location.id, coach_id: coach.id,
      starts_at: starts_at + 1.hour, ends_at: starts_at + 2.hours, capacity: 10, price: 20
    })
    expect(second.success?).to be true
  end
end
