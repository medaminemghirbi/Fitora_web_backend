require "rails_helper"

RSpec.describe AttendanceRecord do
  it "allows only one attendance record per booking" do
    booking = create(:booking)
    create(:attendance_record, booking: booking)
    duplicate = build(:attendance_record, booking: booking)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:booking_id]).to be_present
  end

  it "is valid without a marked_by user" do
    attendance_record = build(:attendance_record, marked_by: nil)
    expect(attendance_record).to be_valid
  end

  it "exposes the status enum with predicate methods" do
    attendance_record = build(:attendance_record, status: :late)

    expect(attendance_record).to be_late
    expect(attendance_record).not_to be_present
  end
end
