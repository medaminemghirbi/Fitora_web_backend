# Every foreign key already has a leading index, but three of the busiest
# queries in the app filter on a second column past that FK and weren't
# served as an index-only/index-range scan:
#
#   - Session's own capacity check (Session#confirmed_bookings_count /
#     #held_bookings_count, called on every booking attempt) does
#     `bookings.where(session_id: ..., status: ...).count` — the single
#     hottest write-path query at booking-rush concurrency.
#   - The "browse classes to book" screen (Me::SessionsController) and the
#     owner dashboard's "today's schedule" both do
#     `sessions.where(location_id: ..., starts_at: range).order(:starts_at)`
#     via the location join — the busiest read path in the product.
#   - A coach's own schedule (SessionsController/AttendanceController when
#     `current_staff_member.coach?`) is the same shape keyed on coach_id.
#
# The composite indexes below serve those directly, and each replaces a
# single-column index on its own leading column (still covered as the
# index's own leftmost prefix), so no index is left behind purely
# duplicating another.
class AddCompositeIndexesForHotPaths < ActiveRecord::Migration[8.0]
  def change
    remove_index :bookings, :session_id
    add_index :bookings, [ :session_id, :status ]

    remove_index :sessions, :location_id
    remove_index :sessions, :coach_id
    remove_index :sessions, :starts_at
    add_index :sessions, [ :location_id, :starts_at ]
    add_index :sessions, [ :coach_id, :starts_at ]
  end
end
