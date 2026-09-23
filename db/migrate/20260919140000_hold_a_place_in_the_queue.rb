# A waitlist for a full session.
#
# Off by default (CompanySettings FEATURES[:waitlist]): a queue nobody works
# through is worse than a session that is honestly full.
#
# status 4 = waitlisted. 0..3 are already taken (confirmed, cancelled,
# completed, no_show), so the queue gets the next value rather than
# renumbering an enum that is written into every existing row.
#
# The check constraint ties the two facts together in both directions: a
# waitlisted booking always has a place in the queue, and a booking that
# leaves the queue can never keep a stale position.
class HoldAPlaceInTheQueue < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :waitlist_position, :integer, null: true

    add_index :bookings, %i[session_id waitlist_position],
      where: "status = 4", name: "index_bookings_waitlist_order"

    add_check_constraint :bookings,
      "(status = 4) = (waitlist_position IS NOT NULL)",
      name: "waitlist_position_iff_waitlisted"
  end
end
