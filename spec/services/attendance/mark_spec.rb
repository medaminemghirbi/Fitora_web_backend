require "rails_helper"

RSpec.describe Attendance::Mark do
  it "creates an attendance record for a booking" do
    booking = create(:booking, status: :confirmed)
    coach_user = create(:user)

    result = described_class.call(booking: booking, status: :present, marked_by: coach_user)

    expect(result.success?).to be true
    expect(result.attendance_record).to be_present
    expect(result.attendance_record.checked_in_at).to be_nil
  end

  it "is idempotent — marking the same booking twice updates the one record instead of erroring" do
    booking = create(:booking, status: :confirmed)
    marker = create(:user)

    first = described_class.call(booking: booking, status: :present, marked_by: marker)
    second = described_class.call(booking: booking, status: :absent, marked_by: marker)

    expect(second.success?).to be true
    expect(AttendanceRecord.where(booking: booking).count).to eq(1)
    expect(AttendanceRecord.find_by(booking: booking).status).to eq("absent")
  end

  it "records checked_in_at for a check-in style mark" do
    booking = create(:booking, status: :confirmed)
    marker = create(:user)

    result = described_class.call(booking: booking, status: :present, marked_by: marker, checked_in_at: Time.current)

    expect(result.attendance_record.checked_in_at).to be_present
  end
end
