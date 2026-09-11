require "rails_helper"

RSpec.describe CheckIns::Create do
  it "marks the booking present with the current time as the check-in time" do
    booking = create(:booking, status: :confirmed)
    staff = create(:user)

    travel_to Time.zone.parse("2026-01-10 09:00:00") do
      result = described_class.call(booking: booking, marked_by: staff)

      expect(result.success?).to be true
      expect(result.attendance_record.status).to eq("present")
      expect(result.attendance_record.marked_by).to eq(staff)
      expect(result.attendance_record.checked_in_at).to eq(Time.current)
    end
  end

  it "persists exactly one attendance record for the booking" do
    booking = create(:booking, status: :confirmed)
    staff = create(:user)

    described_class.call(booking: booking, marked_by: staff)

    expect(AttendanceRecord.where(booking: booking).count).to eq(1)
  end

  it "is idempotent — checking in twice updates the same record" do
    booking = create(:booking, status: :confirmed)
    staff = create(:user)

    first = described_class.call(booking: booking, marked_by: staff)
    second = described_class.call(booking: booking, marked_by: staff)

    expect(second.success?).to be true
    expect(second.attendance_record.id).to eq(first.attendance_record.id)
    expect(AttendanceRecord.where(booking: booking).count).to eq(1)
  end
end
