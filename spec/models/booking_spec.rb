require "rails_helper"

RSpec.describe Booking do
  it "rejects a negative amount" do
    booking = build(:booking, amount: -1)
    expect(booking).not_to be_valid
    expect(booking.errors[:amount]).to be_present
  end

  describe "held-status uniqueness" do
    it "prevents a second confirmed booking for the same client and session" do
      session = create(:session, capacity: 5)
      client = create(:client)
      create(:booking, client: client, session: session, status: :confirmed)
      duplicate = build(:booking, client: client, session: session, status: :confirmed)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:client_id]).to include("has already booked this session")
    end

    it "does not apply the uniqueness check to non-held statuses" do
      session = create(:session, capacity: 5)
      client = create(:client)
      create(:booking, client: client, session: session, status: :cancelled)
      second = build(:booking, client: client, session: session, status: :cancelled)

      expect(second).to be_valid
    end

    it "allows a new confirmed booking once the earlier one for that session was cancelled" do
      session = create(:session, capacity: 5)
      client = create(:client)
      create(:booking, client: client, session: session, status: :cancelled)
      second = build(:booking, client: client, session: session, status: :confirmed)

      expect(second).to be_valid
    end
  end

  describe ".held" do
    it "returns only bookings in a held status" do
      confirmed = create(:booking, status: :confirmed)
      cancelled = create(:booking, status: :cancelled)

      expect(Booking.held).to include(confirmed)
      expect(Booking.held).not_to include(cancelled)
    end
  end

  it "destroys its attendance record when the booking is destroyed" do
    booking = create(:booking)
    attendance_record = create(:attendance_record, booking: booking)

    booking.destroy

    expect(AttendanceRecord.exists?(attendance_record.id)).to be false
  end

  it "nullifies its payments' booking reference instead of deleting them when destroyed" do
    booking = create(:booking)
    payment = create(:payment, booking: booking, client: booking.client)

    booking.destroy

    expect(payment.reload.booking_id).to be_nil
  end
end
