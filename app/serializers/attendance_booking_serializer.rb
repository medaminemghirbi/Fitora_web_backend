# Serializes a booking together with its attendance status, for the coach
# session view / receptionist check-in list.
class AttendanceBookingSerializer
  def initialize(booking)
    @booking = booking
  end

  def as_json(*)
    {
      booking_id: booking.id,
      client: { id: booking.client.id, full_name: booking.client.full_name, phone: booking.client.phone },
      booking_status: booking.status,
      attendance: booking.attendance_record && {
        status: booking.attendance_record.status,
        checked_in_at: booking.attendance_record.checked_in_at,
        checked_out_at: booking.attendance_record.checked_out_at
      }
    }
  end

  private

  attr_reader :booking
end
