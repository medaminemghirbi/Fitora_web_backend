# Gives a session a room, and stops two sessions being in it at once.
#
# The constraint is the point. A room being double-booked is not a warning to
# show later, it is two groups of people arriving at the same door — and an
# application-level check is a race, not a rule. This mirrors
# no_overlapping_coach_sessions exactly, down to the scheduled-only
# predicate: a CANCELLED session must not keep holding its room.
#
# Nullable, because spaces are opt-in. A company with the feature off leaves
# it null forever and the constraint never applies to it.
class PutASessionInARoom < ActiveRecord::Migration[8.1]
  def change
    add_reference :sessions, :space, type: :uuid, null: true, foreign_key: true, index: true

    add_exclusion_constraint :sessions,
      "space_id WITH =, tsrange(starts_at, ends_at) WITH &&",
      where: "status = 0 AND space_id IS NOT NULL",
      using: :gist,
      name: "no_overlapping_space_sessions"
  end
end
