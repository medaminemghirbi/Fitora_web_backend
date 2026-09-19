# A staff member had two roles: an integer enum (`role`) and a foreign key to
# the configurable Role table (`role_id`), kept in step by a
# before_validation hook. Two sources of truth for one fact, and the hook
# existed only to stop them drifting.
#
# The Role table wins. It is the one an owner can actually edit, it is what
# permissions resolve through, and it is the only one that can describe a
# custom role.
#
# The enum also carried a second, unrelated fact — whether this login is a
# coach — which is why it survived this long. That fact moves to where it was
# always really recorded: a coach login is one with a linked Coach row
# (staff_members.coach_id). The five places that narrow a coach to their own
# sessions all key off coach_id already, so this makes the check honest
# rather than changing it.
class GiveAStaffMemberOneRoleNotTwo < ActiveRecord::Migration[8.1]
  def up
    # enum was { receptionist: 0, coach: 1 }
    execute(<<~SQL)
      UPDATE staff_members sm
      SET role_id = r.id
      FROM roles r
      WHERE r.company_id = sm.company_id
        AND r.key = CASE sm.role WHEN 1 THEN 'coach' ELSE 'receptionist' END
        AND sm.role_id IS NULL
    SQL

    orphans = select_values("SELECT DISTINCT company_id::text FROM staff_members WHERE role_id IS NULL")
    if orphans.any?
      raise ActiveRecord::IrreversibleMigration, <<~MSG
        #{orphans.size} company/companies have staff with no role to migrate to,
        because their built-in roles were never seeded: #{orphans.join(', ')}.

        Seed them first, then re-run:
          Company.where(id: %w[#{orphans.join(' ')}]).each { |c| Role.seed_defaults_for(c) }

        Refusing to proceed rather than leave staff without permissions.
      MSG
    end

    change_column_null :staff_members, :role_id, false
    remove_column :staff_members, :role
  end

  def down
    add_column :staff_members, :role, :integer, null: false, default: 0
    execute(<<~SQL)
      UPDATE staff_members sm
      SET role = CASE WHEN sm.coach_id IS NOT NULL THEN 1 ELSE 0 END
    SQL
    change_column_null :staff_members, :role_id, true
  end
end
