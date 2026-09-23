# Taking a payment at the desk and reading what the gym earns are two
# different jobs. They were one permission ("reports"), which meant every
# receptionist and moderator could read the revenue screen.
#
# Adds the "revenue" capability and grants it to the owner role only. Any
# custom role an owner built keeps exactly what it had — granting it on
# their behalf is their decision, not this migration's.
class SeparateTakingMoneyFromReadingIt < ActiveRecord::Migration[8.1]
  def up
    Role.where(key: "owner").find_each do |role|
      next if role.permissions.include?("revenue")

      role.update_columns(permissions: Permission.sanitize(role.permissions + [ "revenue" ]))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
