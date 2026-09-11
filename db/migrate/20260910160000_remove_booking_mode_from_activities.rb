# Booking is now always tied to the member's contract — there is no
# per-activity "free / pay-per-booking / contract-required" choice anymore.
# Bookings::Create requires a contract covering (location + activity) for
# every booking.
class RemoveBookingModeFromActivities < ActiveRecord::Migration[8.0]
  def up
    remove_column :activities, :booking_mode
  end

  def down
    add_column :activities, :booking_mode, :integer, default: 0, null: false
  end
end
