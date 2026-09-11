# "Manager" is gone — the staff roles are Owner / Réception / Coach. The
# `staff_members.role` enum drops to { receptionist: 0, coach: 1 } (it is now
# just the *kind* of login, not the permission set). Remap existing rows,
# repoint any manager-assigned staff at the receptionist Role, then delete
# the built-in "manager" Role of every company.
class DropManagerRole < ActiveRecord::Migration[8.0]
  def up
    # enum remap: old manager(0)+receptionist(1) -> receptionist(0); coach(2) -> coach(1)
    execute("UPDATE staff_members SET role = CASE role WHEN 2 THEN 1 ELSE 0 END")

    # repoint staff on a built-in "manager" Role at the same company's "receptionist" Role
    execute(<<~SQL)
      UPDATE staff_members sm
      SET role_id = rcpt.id
      FROM roles mgr
      JOIN roles rcpt ON rcpt.company_id = mgr.company_id AND rcpt.key = 'receptionist'
      WHERE sm.role_id = mgr.id AND mgr.key = 'manager' AND mgr.builtin = TRUE
    SQL

    execute("DELETE FROM roles WHERE key = 'manager' AND builtin = TRUE")
    # `staff_members.role` default stays 0 — which now means `receptionist`.
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
