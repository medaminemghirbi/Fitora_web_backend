require "rails_helper"

RSpec.describe RecurringSchedulesGenerateJob do
  it "calls RecurringSchedules::Generate for every active schedule still within its window" do
    active_schedule = create(:recurring_schedule, active: true, ends_on: 10.days.from_now.to_date)
    expired_schedule = create(:recurring_schedule, active: true, starts_on: 10.days.ago.to_date, ends_on: 1.day.ago.to_date)
    inactive_schedule = create(:recurring_schedule, active: false, ends_on: 10.days.from_now.to_date)

    allow(RecurringSchedules::Generate).to receive(:call)

    described_class.new.perform

    expect(RecurringSchedules::Generate).to have_received(:call).with(schedule: active_schedule).once
    expect(RecurringSchedules::Generate).not_to have_received(:call).with(schedule: expired_schedule)
    expect(RecurringSchedules::Generate).not_to have_received(:call).with(schedule: inactive_schedule)
  end

  it "calls the service for every active schedule across every company" do
    schedule_a = create(:recurring_schedule, active: true, ends_on: 5.days.from_now.to_date)
    schedule_b = create(:recurring_schedule, active: true, ends_on: 5.days.from_now.to_date)

    allow(RecurringSchedules::Generate).to receive(:call)

    described_class.new.perform

    expect(RecurringSchedules::Generate).to have_received(:call).with(schedule: schedule_a).once
    expect(RecurringSchedules::Generate).to have_received(:call).with(schedule: schedule_b).once
  end
end
