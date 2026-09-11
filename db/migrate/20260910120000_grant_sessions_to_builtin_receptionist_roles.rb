# The built-in "Réception" role now includes "sessions" (schedule editing)
# so a receptionist can plan the week's sessions, not just take bookings.
# Role.seed_defaults_for only sets permissions on brand-new role rows, so
# existing companies' built-in receptionist roles need this backfill.
class GrantSessionsToBuiltinReceptionistRoles < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      UPDATE roles
      SET permissions = array_append(permissions, 'sessions'),
          updated_at = now()
      WHERE key = 'receptionist'
        AND builtin = TRUE
        AND NOT ('sessions' = ANY (permissions))
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE roles
      SET permissions = array_remove(permissions, 'sessions'),
          updated_at = now()
      WHERE key = 'receptionist'
        AND builtin = TRUE
    SQL
  end
end
