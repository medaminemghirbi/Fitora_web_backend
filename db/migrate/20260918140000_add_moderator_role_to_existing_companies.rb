# The Modérateur role is new: the level between the owner and the coaches,
# and the only one below the owner allowed to add coaches. Companies created
# before it exists need it too, and seed_defaults_for is idempotent — it
# adds what is missing and leaves re-permissioned roles alone.
class AddModeratorRoleToExistingCompanies < ActiveRecord::Migration[8.1]
  def up
    Company.find_each { |company| Role.seed_defaults_for(company) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Deleting a role would orphan whoever was assigned to it."
  end
end
