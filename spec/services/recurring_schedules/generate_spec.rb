require "rails_helper"

RSpec.describe RecurringSchedules::Generate do
  it "generates a session for every matching weekday within the window" do
    monday = Date.current.next_occurring(:monday)
    schedule = create(:recurring_schedule, weekdays: [ 1 ], starts_on: monday, ends_on: monday + 14.days)

    result = described_class.call(schedule: schedule)

    expect(result.created_count).to eq(3) # 3 Mondays across a 2-week window inclusive of the start
    expect(schedule.sessions.count).to eq(3)
    expect(schedule.sessions.pluck(:starts_at).map(&:wday).uniq).to eq([ 1 ])
  end

  it "never generates further ahead than the 90-day horizon, even with a much later ends_on" do
    schedule = create(:recurring_schedule, weekdays: [ 0, 1, 2, 3, 4, 5, 6 ], starts_on: Date.current, ends_on: 2.years.from_now.to_date)

    described_class.call(schedule: schedule)

    last_session = schedule.sessions.order(:starts_at).last
    expect(last_session.starts_at.to_date).to be <= (Date.current + RecurringSchedule::GENERATION_HORIZON)
  end

  it "is idempotent — running generation twice does not duplicate sessions" do
    schedule = create(:recurring_schedule, weekdays: [ 1 ], starts_on: Date.current, ends_on: 14.days.from_now.to_date)

    described_class.call(schedule: schedule)
    count_after_first_run = schedule.sessions.count
    described_class.call(schedule: schedule)

    expect(schedule.sessions.count).to eq(count_after_first_run)
  end

  it "records a conflict instead of raising when a generated slot would double-book the coach" do
    monday = Date.current.next_occurring(:monday)
    coach = create(:coach)
    location = create(:location, company: coach.company)
    create(:coach_location, coach: coach, location: location)
    activity_a = create(:activity, location: location, duration: 60)
    activity_b = create(:activity, location: location, duration: 60)

    # An existing manual session already occupies this coach at this exact time.
    create(:session, activity: activity_a, location: location, coach: coach,
                      starts_at: monday.to_time(:utc).change(hour: 18), ends_at: monday.to_time(:utc).change(hour: 19))

    schedule = create(:recurring_schedule, activity: activity_b, location: location, coach: coach,
                                            weekdays: [ 1 ], start_time: "18:00", starts_on: monday, ends_on: monday)

    result = described_class.call(schedule: schedule)

    expect(result.created_count).to eq(0)
    expect(result.conflict_errors.size).to eq(1)
    expect(result.conflict_errors.first[:error]).to eq("Coach already has a session at that time.")
  end
end
