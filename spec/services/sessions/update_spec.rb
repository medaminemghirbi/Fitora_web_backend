require "rails_helper"

RSpec.describe Sessions::Update do
  it "updates the session with valid attributes" do
    session = create(:session, capacity: 10)

    result = described_class.call(session: session, attributes: { capacity: 15 })

    expect(result.success?).to be true
    expect(result.error).to be_nil
    expect(result.session.capacity).to eq(15)
    expect(session.reload.capacity).to eq(15)
  end

  it "rejects an invalid update" do
    session = create(:session, capacity: 10)

    result = described_class.call(session: session, attributes: { capacity: 0 })

    expect(result.success?).to be false
    expect(result.session).to be_nil
    expect(result.error).to be_present
    expect(session.reload.capacity).to eq(10)
  end

  it "rejects an update that would overlap another of the coach's sessions with a friendly error" do
    company = create(:company)
    activity = create(:activity, company: company)
    coach = create(:coach, company: company)

    starts_at = 2.days.from_now.change(hour: 18)
    create(:session, activity: activity, company: company, coach: coach,
                      starts_at: starts_at, ends_at: starts_at + 1.hour)
    session = create(:session, activity: activity, company: company, coach: coach,
                                starts_at: starts_at + 2.hours, ends_at: starts_at + 3.hours)

    result = described_class.call(
      session: session,
      attributes: { starts_at: starts_at + 30.minutes, ends_at: starts_at + 90.minutes }
    )

    expect(result.success?).to be false
    expect(result.session).to be_nil
    expect(result.error).to eq("Coach already has a session at that time.")
  end
end
