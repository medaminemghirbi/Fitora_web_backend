# Defense in depth alongside the row-locking fix in Bookings::Create
# (a security-audit finding: the eligibility check and the credit
# decrement used to happen against an unlocked row, letting two
# concurrent bookings both pass the check and drive this negative).
# A DB-level floor means no future code path — a rake task, a console
# fix, a service that forgets to lock — can silently persist a negative
# balance either.
class AddCheckConstraintToContractPeriodsRemainingBookings < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :contract_periods,
                          "remaining_bookings IS NULL OR remaining_bookings >= 0",
                          name: "remaining_bookings_not_negative"
  end
end
