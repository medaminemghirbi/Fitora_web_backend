# An owner can now run more than one company. company_limit is how many
# they're allowed to create (nil = unlimited — plain NULL is fine here,
# this is a gate check, not a uniqueness key); active_company_id is which
# one their session is currently scoped to (see Api::V1::BaseController
# #current_company) — switched via Api::V1::CompaniesController#switch.
#
# Every existing owner already has exactly one company (companies.owner_id
# was unique until this migration) — company_limit: 1 is a correct default
# for all of them, not just new signups, and the backfill makes that
# company their active one so nothing changes behaviorally for anyone
# until they actually add a second company.
class AddMultiCompanySupportToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :company_limit, :integer
    change_column_default :users, :company_limit, from: nil, to: 1
    execute "UPDATE users SET company_limit = 1 WHERE role = 0" # owner

    add_reference :users, :active_company, type: :uuid, index: true
    # A separate add_foreign_key, not the add_reference shorthand's
    # `foreign_key: { on_delete: }` — that shorthand silently drops
    # on_delete in this Rails version. on_delete: :nullify matters here
    # specifically: User#companies is dependent: :destroy, and a company
    # being destroyed while it's still someone's active_company (including
    # its own owner mid-#destroy, which deletes each owned company before
    # the user row itself) must not raise a FK violation — it should just
    # clear the pointer.
    add_foreign_key :users, :companies, column: :active_company_id, on_delete: :nullify

    execute(<<~SQL.squish)
      UPDATE users SET active_company_id = companies.id
      FROM companies WHERE companies.owner_id = users.id
    SQL

    remove_index :companies, :owner_id
    add_index :companies, :owner_id
  end

  def down
    remove_index :companies, :owner_id
    add_index :companies, :owner_id, unique: true

    remove_foreign_key :users, :companies, column: :active_company_id
    remove_reference :users, :active_company
    remove_column :users, :company_limit
  end
end
